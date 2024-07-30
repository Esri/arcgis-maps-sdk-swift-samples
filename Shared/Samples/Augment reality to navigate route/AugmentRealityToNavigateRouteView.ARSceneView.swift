// Copyright 2024 Esri
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
import ArcGISToolkit
import AVFoundation
import SwiftUI

extension AugmentRealityToNavigateRouteView {
    /// A world scale scene view displaying route graphics from a given model.
    struct ARRouteSceneView: View {
        /// The view model for scene view in the sample.
        @ObservedObject var model: SceneModel
        
        /// A Boolean value indicating whether the use is navigating the route.
        @State private var isNavigating = false
        
        /// The error shown in the error alert.
        @State private var error: Error?
        
        var body: some View {
            VStack(spacing: 0) {
                WorldScaleSceneView { _ in
                    SceneView(
                        scene: model.scene,
                        graphicsOverlays: [model.routeGraphicsOverlay]
                    )
                }
                .calibrationButtonAlignment(.bottomLeading)
                .onCalibratingChanged { isPresented in
                    model.scene.baseSurface.opacity = isPresented ? 0.6 : 0
                }
                .task {
                    do {
                        try await model.startTrackingLocation()
                    } catch {
                        self.error = error
                    }
                }
                .overlay(alignment: .top) {
                    Text(model.statusText)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(8)
                        .background(.regularMaterial, ignoresSafeAreaEdges: .horizontal)
                }
                .onAppear {
                    model.statusText = "Adjust calibration before starting."
                }
                .onDisappear {
                    model.stopNavigation()
                }
                Divider()
            }
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button("Start") {
                        isNavigating = true
                    }
                    .disabled(isNavigating)
                    .task(id: isNavigating) {
                        guard isNavigating else { return }
                        do {
                            try await model.startNavigation()
                        } catch {
                            self.error = error
                        }
                    }
                }
            }
            .errorAlert(presentingError: $error)
        }
    }
}

extension AugmentRealityToNavigateRouteView {
    // MARK: Scene Model
    
    /// The view model for scene view in the sample.
    @MainActor
    class SceneModel: ObservableObject {
        /// A scene with an imagery basemap.
        let scene = Scene(basemapStyle: .arcGISImagery)
        
        /// The graphics overlay containing a graphic for the route.
        private(set) var routeGraphicsOverlay = GraphicsOverlay()
        
        /// The elevation surface set to the base surface of the scene.
        private(set) var elevationSurface: Surface = {
            let elevationSurface = Surface()
            elevationSurface.navigationConstraint = .unconstrained
            elevationSurface.opacity = 0
            elevationSurface.backgroundGrid.isVisible = false
            return elevationSurface
        }()
        
        /// The elevation source with elevation service URL.
        private var elevationSource = ArcGISTiledElevationSource(url: .worldElevationService)
        
        /// The route tracker.
        private(set) var routeTracker: RouteTracker?
        
        /// The route result.
        var routeResult: RouteResult?
        
        /// An AVSpeechSynthesizer for text to speech.
        private let speechSynthesizer = AVSpeechSynthesizer()
        
        /// The route task that solves the route using the online routing service, using API key authentication.
        let routeTask = RouteTask(url: URL(string: "https://route-api.arcgis.com/arcgis/rest/services/World/Route/NAServer/Route_World")!)
        
        /// The parameters for route task to solve a route.
        var routeParameters = RouteParameters()
        
        /// The data source to track device location and provide updates to route tracker.
        let locationDataSource = SystemLocationDataSource()
        
        /// The status text displayed to the user.
        @Published var statusText = ""
        
        init() {
            elevationSurface.addElevationSource(elevationSource)
            scene.baseSurface = elevationSurface
        }
        
        /// Loads the scene elevation source.
        func loadElevationSource() async throws {
            await scene.baseSurface.elevationSources.load()
        }
        
        /// Tracks the location datasource locations.
        func startTrackingLocation() async throws {
            for await location in locationDataSource.locations {
                try await routeTracker?.track(location)
            }
        }
        
        /// Creates a graphics overlay and adds a graphic (with solid yellow 3D tube symbol)
        /// to represent the route.
        func makeRouteOverlay() async throws {
            let graphicsOverlay = GraphicsOverlay()
            graphicsOverlay.sceneProperties.surfacePlacement = .absolute
            let strokeSymbolLayer = SolidStrokeSymbolLayer(
                width: 1.0,
                color: .yellow,
                lineStyle3D: .tube
            )
            let polylineSymbol = MultilayerPolylineSymbol(symbolLayers: [strokeSymbolLayer])
            let polylineRenderer = SimpleRenderer(symbol: polylineSymbol)
            graphicsOverlay.renderer = polylineRenderer
            
            if let routeResult,
               let originalPolyline = routeResult.routes.first?.geometry,
               let elevatedPolyline = try await addingElevation(3, to: originalPolyline) {
                let routeGraphic = Graphic(geometry: elevatedPolyline)
                graphicsOverlay.addGraphic(routeGraphic)
            }
            
            routeGraphicsOverlay = graphicsOverlay
        }
        
        /// Densifies the polyline geometry so the elevation can be adjusted every 0.3 meters and adds
        /// an elevation to the geometry.
        /// - Parameters:
        ///   - z: The z elevation.
        ///   - polyline: The polyline geometry of the route.
        /// - Returns: A polyline with adjusted elevation.
        private func addingElevation(_ z: Double, to polyline: Polyline) async throws -> Polyline? {
            if let densifiedPolyline = GeometryEngine.densify(polyline, maxSegmentLength: 0.3) as? Polyline {
                let polylineBuilder = PolylineBuilder(spatialReference: densifiedPolyline.spatialReference)
                for part in densifiedPolyline.parts {
                    for point in part.points {
                        let elevation = try await elevationSurface.elevation(at: point)
                        let newPoint = GeometryEngine.makeGeometry(from: point, z: elevation + z)
                        // Put the new point 3 meters above the ground elevation.
                        polylineBuilder.add(newPoint)
                    }
                }
                return polylineBuilder.toGeometry()
            } else {
                return nil
            }
        }
        
        /// Starts navigating the route.
        func startNavigation() async throws {
            guard let routeResult = routeResult else { return }
            routeTracker = RouteTracker(
                routeResult: routeResult,
                routeIndex: 0,
                skipsCoincidentStops: true
            )
            guard let routeTracker else { return }
            
            routeTracker.voiceGuidanceUnitSystem = Locale.current.measurementSystem == .us
            ? .imperial
            : .metric
            
            try await routeTask.load()
            
            if routeTask.info.supportsRerouting,
               let reroutingParameters = ReroutingParameters(
                routeTask: routeTask,
                routeParameters: routeParameters
               ) {
                try await routeTracker.enableRerouting(using: reroutingParameters)
            }
            
            statusText = "Navigation will start."
            await startTracking()
        }
        
        /// Stops navigating the route.
        func stopNavigation() {
            speechSynthesizer.stopSpeaking(at: .word)
            routeTracker = nil
        }
        
        /// Starts monitoring multiple asynchronous streams of information.
        private func startTracking() async {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.trackStatus() }
                group.addTask { await self.trackVoiceGuidance() }
            }
        }
        
        /// Monitors the asynchronous stream of voice guidances.
        private func trackVoiceGuidance() async {
            guard let routeTracker = routeTracker else { return }
            for try await voiceGuidance in routeTracker.voiceGuidances {
                speechSynthesizer.stopSpeaking(at: .word)
                speechSynthesizer.speak(AVSpeechUtterance(string: voiceGuidance.text))
            }
        }
        
        /// Monitors the asynchronous stream of tracking statuses.
        ///
        /// Updates the route's traversed and remaining graphics when new statuses are delivered.
        private func trackStatus() async {
            guard let routeTracker else { return }
            for await status in routeTracker.$trackingStatus {
                guard let status else { continue }
                switch status.destinationStatus {
                case .notReached, .approaching:
                    if let route = routeResult?.routes.first {
                        let currentManeuver = route.directionManeuvers[status.currentManeuverIndex]
                        statusText = currentManeuver.text
                    }
                case .reached:
                    statusText = "You have arrived!"
                @unknown default:
                    break
                }
            }
        }
    }
}

private extension URL {
    /// The URL of the Terrain 3D ArcGIS REST Service.
    static var worldElevationService: URL {
        URL(string: "https://elevation3d.arcgis.com/arcgis/rest/services/WorldElevation3D/Terrain3D/ImageServer")!
    }
}
