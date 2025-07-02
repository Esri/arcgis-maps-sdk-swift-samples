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
    
    var body: some View {
        SceneView(
            scene: model.scene,
            graphicsOverlays: [model.graphicsOverlay],
            analysisOverlays: [model.analysisOverlay]
        )
        .overlay(alignment: .top) {
            HStack {
                Text("Visibility: ")
                Text("Status")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(.thinMaterial, ignoresSafeAreaEdges: .horizontal)
        }
        .task {
            await model.addGraphics()
        }
        .errorAlert(presentingError: $model.error)
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
        var visible: Bool = false
        private var frameIndex: Int = 0
        private let frameMax: Int = 120
        private var pointIndex: Int = 0
        var error: Error?
        let scene: ArcGIS.Scene = {
            // Creates a scene and set an initial viewpoint.
            let scene = Scene(basemapStyle: .arcGISImagery)
            let point = Point(
                x: -73.984988,
                y: 40.748131,
                spatialReference: .wgs84
            )
            scene.initialViewpoint = Viewpoint(center: point, scale: 1600)
            // Add base surface from elevation service.
            let elevationSource = ArcGISTiledElevationSource(url: .elevationService)
            let surface = Surface()
            surface.addElevationSource(elevationSource)
            scene.baseSurface = surface
            var buildingLayer = ArcGISSceneLayer(url: .buildingsService)
            scene.addOperationalLayer(buildingLayer)
            return scene
        }()
        var graphicsOverlay = GraphicsOverlay()
        var analysisOverlay = AnalysisOverlay()
        private var lineOfSight: GeoElementLineOfSight?
        private var taxiGraphic: Graphic?
        nonisolated(unsafe) private var displayLink: CADisplayLink!
        private var observerGraphic: Graphic?
        private var point = Point(
            x: -73.984988,
            y: 40.748131,
            spatialReference: .wgs84
        )

        deinit {
            displayLink.invalidate()
        }
        
        func addGraphics() async {
            graphicsOverlay.sceneProperties = .init(surfacePlacement: .relative)
            displayLink = makeDisplayLink()
            let symbol = SimpleMarkerSceneSymbol(
                style: .sphere,
                color: .red,
                height: 5,
                width: 5,
                depth: 5,
                anchorPosition: .bottom
            )
            observerGraphic = Graphic(
                geometry: point,
                symbol: symbol
            )
            if let observerGraphic = observerGraphic {
                graphicsOverlay.addGraphic(observerGraphic)
            }
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
                if let observer = observerGraphic, let taxi = taxiGraphic {
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
                displayLink.isPaused = false
            } catch {
                self.error = error
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
