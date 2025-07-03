// Copyright 2025 Esri
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import ArcGIS
import SwiftUI

struct ShowLineOfSightBetweenGeoelementsView: View {
    @State private var model = Model()
    
    /// Manages the presentation state of the menu.
    @State private var isPresented = false
    
    var body: some View {
        SceneView(
            scene: model.scene,
            graphicsOverlays: [model.graphicsOverlay],
            analysisOverlays: [model.analysisOverlay]
        )
        .overlay(alignment: .top) {
            HStack {
                Text("Visibility:")
                Text(model.visibilityStatus)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(.thinMaterial, ignoresSafeAreaEdges: .horizontal)
        }
        .task {
            await model.addGraphics()
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button("Settings") {
                    isPresented = true
                }
                .sheet(isPresented: $isPresented) {
                    settingsSheet
                }
            }
        }
        .errorAlert(presentingError: $model.error)
    }
    
    /// The menu.
    private var settingsSheet: some View {
        NavigationStack {
            Form {
                let heightRange = 1.0...1_000.0
                var numberFormat: FloatingPointFormatStyle<Double> {
                    .init().precision(.fractionLength(0))
                }
                
                LabeledContent(
                    "Height",
                    value: model.height,
                    format: numberFormat
                )
                
                Slider(
                    value: $model.height,
                    in: heightRange,
                    step: 1
                ) {
                    Text("Height")
                } minimumValueLabel: {
                    Text(heightRange.lowerBound, format: numberFormat)
                } maximumValueLabel: {
                    Text(heightRange.upperBound, format: numberFormat)
                }
                .listRowSeparator(.hidden, edges: .top)
            }
            .presentationDetents([.fraction(0.25)])
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

private extension ShowLineOfSightBetweenGeoelementsView {
    @MainActor
    @Observable
    final class Model {
        private let points: [Point] = [
            Point(x: -73.984513, y: 40.748469, spatialReference: .wgs84),
            Point(x: -73.985068, y: 40.747786, spatialReference: .wgs84),
            Point(x: -73.983452, y: 40.747091, spatialReference: .wgs84),
            Point(x: -73.982961, y: 40.747762, spatialReference: .wgs84)
        ]
        /// Controls the complexity of the geometries and the approximation of the ellipse curve.
        var height = 1_000.0
        private var frameIndex: Int = 0
        private let frameMax: Int = 120
        private var pointIndex: Int = 0
        var error: Error?
        let scene: ArcGIS.Scene = {
            // Creates a scene and set an initial viewpoint.
            let scene = Scene(basemapStyle: .arcGISImagery)
            // Add base surface from elevation service.
            let elevationSource = ArcGISTiledElevationSource(url: .elevationService)
            let surface = Surface()
            surface.addElevationSource(elevationSource)
            scene.baseSurface = surface
            var buildingLayer = ArcGISSceneLayer(url: .buildingsService)
            scene.addOperationalLayer(buildingLayer)
            return scene
        }()
        var graphicsOverlay = GraphicsOverlay() {
            didSet {
                let renderer = SimpleRenderer()
                renderer.sceneProperties.headingExpression = ("[HEADING]")
                graphicsOverlay.renderer = renderer
            }
        }
        var analysisOverlay = AnalysisOverlay()
        private var lineOfSight: GeoElementLineOfSight?
        private var taxiGraphic: Graphic?
        private var displayLink: CADisplayLink!
        private var observerGraphic: Graphic?
        var visibilityStatus = ""
        let symbol = SimpleMarkerSceneSymbol(
            style: .sphere,
            color: .red,
            height: 5,
            width: 5,
            depth: 5,
            anchorPosition: .bottom
        )
        private var point = Point(
            x: -73.984988,
            y: 40.748131,
            spatialReference: .wgs84
        )
        
        func addGraphics() async {
            graphicsOverlay.sceneProperties = .init(surfacePlacement: .relative)
            displayLink = makeDisplayLink()
            let sceneSymbol = ModelSceneSymbol(url: .taxi)
            do {
                try await sceneSymbol.load()
                sceneSymbol.anchorPosition = .bottom
                taxiGraphic = Graphic(
                    geometry: Point(
                        x: -73.984513,
                        y: 40.748469,
                        spatialReference: .wgs84
                    ),
                    symbol: sceneSymbol
                )
                observerGraphic = Graphic(
                    geometry: point,
                    symbol: symbol
                )
                addGraphicsToOverlays()
                displayLink.isPaused = false
            } catch {
                self.error = error
            }
        }
        
        private func addGraphicsToOverlays() {
            if let observer = observerGraphic, let taxi = taxiGraphic {
                graphicsOverlay.addGraphic(observer)
                if let observerPoint = observer.geometry as? Point {
                    let camera = Camera(
                        lookingAt: observerPoint,
                        distance: 700.0,
                        heading: -30.0,
                        pitch: 45.0,
                        roll: 0.0
                    )
                    scene.initialViewpoint = Viewpoint(
                        boundingGeometry: observerPoint,
                        camera: camera
                    )
                }
                graphicsOverlay.addGraphic(taxi)
                lineOfSight = GeoElementLineOfSight(
                    observer: observer,
                    target: taxi
                )
                lineOfSight?.targetOffsetZ = 2
                if let lineOfSight = lineOfSight {
                    analysisOverlay.addAnalysis(lineOfSight)
                }
            }
        }
        
        /// Creates a display link timer for the image overlay animation.
        /// - Returns: A new `CADisplayLink` object.
        private func makeDisplayLink() -> CADisplayLink {
            // Create new display link.
            let newDisplayLink = CADisplayLink(
                target: self,
                selector: #selector(animateTaxi)
            )
            // Set the default frame rate to 60 fps.
            newDisplayLink.preferredFramesPerSecond = 60
            newDisplayLink.isPaused = true
            // Add to main thread common mode run loop, so it is not effected by UI events.
            newDisplayLink.add(to: .main, forMode: .common)
            return newDisplayLink
        }
        
        @objc
        private func animateTaxi() {
            guard let taxiGraphic = taxiGraphic else { return }
            // Increment the frame counter
            frameIndex += 1
            // Reset frame counter when segment is completed
            if frameIndex == frameMax {
                frameIndex = 0
                pointIndex += 1
                if pointIndex == points.count {
                    pointIndex = 0
                }
            }
            let starting = points[pointIndex]
            let ending = points[(pointIndex + 1) % points.count]
            let progress = Double(frameIndex) / Double(frameMax)
            // Interpolate between points
            let intermediatePoint = interpolatedPoint(
                from: starting,
                to: ending,
                progress: progress
            )
            taxiGraphic.geometry = intermediatePoint
            if let distance = GeometryEngine.geodeticDistance(
                from: starting,
                to: ending,
                distanceUnit: .meters,
                azimuthUnit: .degrees,
                curveType: .geodesic
            ) {
                (taxiGraphic.symbol as? ModelSceneSymbol)?.heading = Float(distance.azimuth1.value)
            }
            guard let lineOfSight else { return }
            switch lineOfSight.targetVisibility {
            case .obstructed:
                visibilityStatus = "obstructed"
                taxiGraphic.isSelected = false
            case .visible:
                visibilityStatus = "visible"
                taxiGraphic.isVisible = true
            case .unknown:
                visibilityStatus = "unknown"
                taxiGraphic.isSelected = false
            @unknown default:
                print("error")
            }
        }
        
        private func interpolatedPoint(from: Point, to: Point, progress: Double) -> Point {
            let x = from.x + (to.x - from.x) * progress
            let y = from.y + (to.y - from.y) * progress
            return Point(x: x, y: y, spatialReference: .wgs84)
        }
    }
}

extension URL {
    // URL of the elevation service - provides elevation component of the scene
    static var elevationService: URL {
        URL(string: "https://elevation3d.arcgis.com/arcgis/rest/services/WorldElevation3D/Terrain3D/ImageServer")!
    }
    
    // URL of the building service - provides builiding models
    static var buildingsService: URL {
        URL(string: "https://tiles.arcgis.com/tiles/z2tnIkrLQ2BRzr6P/arcgis/rest/services/Buildings_NewYork_v18/SceneServer/layers/0")!
    }
    
    /// A URL to the loca taxi model files.
    static var taxi: URL {
        Bundle.main.url(forResource: "dolmus", withExtension: "3ds", subdirectory: "Dolmus3ds")!
    }
}

#Preview {
    ShowLineOfSightBetweenGeoelementsView()
}
