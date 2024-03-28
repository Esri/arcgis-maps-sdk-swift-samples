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

struct AugmentRealityToNavigateRouteView: View {
    /// The data model for the selected route.
    @StateObject private var routeDataModel = RouteDataModel()
    /// A Boolean value indicating whether the route planner is showing.
    @State private var isShowingRoutePlanner = true
    /// The location datasource that is used to access the device location.
    @State private var locationDataSource = SystemLocationDataSource()
    /// A scene with an imagery basemap.
    @State private var scene = Scene(basemapStyle: .arcGISImagery)
    /// The elevation surface set to the base surface of the scene.
    @State private var elevationSurface: Surface = {
        let elevationSurface = Surface()
        elevationSurface.navigationConstraint = .unconstrained
        elevationSurface.opacity = 0
        elevationSurface.backgroundGrid.isVisible = false
        return elevationSurface
    }()
    /// The elevation source with elevation service URL.
    @State private var elevationSource = ArcGISTiledElevationSource(url: URL(string: "https://elevation3d.arcgis.com/arcgis/rest/services/WorldElevation3D/Terrain3D/ImageServer")!)
    /// The graphics overlay containing a graphic.
    @State private var graphicsOverlay = GraphicsOverlay()
    /// The status text displayed to the user.
    @State private var statusText = "Adjust calibration before starting."
    /// A Boolean value indicating whether the use is navigatig the route.
    @State private var isNavigating = false
    /// The result of the route selected in the route planner view.
    @State private var routeResult: RouteResult?
    
    init() {
        elevationSurface.addElevationSource(elevationSource)
        scene.baseSurface = elevationSurface
    }
    
    var body: some View {
        if isShowingRoutePlanner {
            RoutePlannerView(isShowing: $isShowingRoutePlanner)
                .onDidSelectRoute { routeGraphic, routeResult  in
                    self.routeResult = routeResult
                    graphicsOverlay = makeRouteOverlay(
                        routeResult: routeResult,
                        routeGraphic: routeGraphic
                    )
                }
                .task {
                    try? await elevationSource.load()
                }
        } else {
            VStack(spacing: 0) {
                WorldScaleSceneView { _ in
                    SceneView(scene: scene, graphicsOverlays: [graphicsOverlay])
                }
                .calibrationButtonAlignment(.bottomLeading)
                .onCalibratingChanged { isPresented in
                    scene.baseSurface.opacity = isPresented ? 0.6 : 0
                }
                .task {
                    try? await locationDataSource.start()
                    
                    for await location in locationDataSource.locations {
                        try? await routeDataModel.routeTracker?.track(location)
                    }
                }
                .overlay(alignment: .top) {
                    Text(statusText)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(8)
                        .background(.regularMaterial, ignoresSafeAreaEdges: .horizontal)
                }
                .onDisappear {
                    Task { await locationDataSource.stop() }
                }
                Divider()
            }
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button("Start") {
                        isNavigating = true
                        Task {
                            do {
                                try await startNavigation()
                            } catch {
                                print("Failed to start navigation.")
                            }
                        }
                    }
                    .disabled(isNavigating)
                }
            }
        }
    }
    
    /// Creates a graphics overlay and adds a graphic (with solid yellow 3D tube symbol)
    /// to represent the route.
    private func makeRouteOverlay(routeResult: RouteResult, routeGraphic: Graphic) -> GraphicsOverlay {
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
        
        if let originalPolyline = routeResult.routes.first?.geometry {
            addingElevation(3, to: originalPolyline) { polyline in
                routeGraphic.geometry = polyline
                graphicsOverlay.addGraphic(routeGraphic)
            }
        }
        
        return graphicsOverlay
    }
    
    /// Densify the polyline geometry so the elevation can be adjusted every 0.3 meters,
    /// and add an elevation to the geometry.
    ///
    /// - Parameters:
    ///   - z: A `Double` value representing z elevation.
    ///   - polyline: The polyline geometry of the route.
    ///   - completion: A completion closure to execute after the polyline is generated with success or not.
    private func addingElevation(
        _ z: Double,
        to polyline: Polyline,
        completion: @escaping (Polyline) -> Void
    ) {
        if let densifiedPolyline = GeometryEngine.densify(polyline, maxSegmentLength: 0.3) as? Polyline {
            let polylineBuilder = PolylineBuilder(spatialReference: densifiedPolyline.spatialReference)
            Task {
                for part in densifiedPolyline.parts {
                    for point in part.points {
                        async let elevation = try await elevationSurface.elevation(at: point)
                        let newPoint = await GeometryEngine.makeGeometry(from: point, z: try elevation + z)
                        // Put the new point 3 meters above the ground elevation.
                        polylineBuilder.add(newPoint)
                    }
                }
                completion(polylineBuilder.toGeometry())
            }
        } else {
            completion(polyline)
        }
    }
    
    /// Starts navigating the route.
    private func startNavigation() async throws {
        guard let routeResult else { return }
        let routeTracker = RouteTracker(
            routeResult: routeResult,
            routeIndex: 0,
            skipsCoincidentStops: true
        )
        guard let routeTracker else { return }
        
        routeTracker.voiceGuidanceUnitSystem = Locale.current.usesMetricSystem ? .metric : .imperial
        
        routeDataModel.routeTracker = routeTracker
        
        do {
            try await routeDataModel.routeTask.load()
        } catch {
            throw error
        }
        
        if routeDataModel.routeTask.info.supportsRerouting,
           let reroutingParameters = ReroutingParameters(
            routeTask: routeDataModel.routeTask,
            routeParameters: routeDataModel.routeParameters
           ) {
            do {
                try await routeTracker.enableRerouting(using: reroutingParameters)
            } catch {
                throw error
            }
        }
        
        statusText = "Navigation will start."
        await startTracking()
    }
    
    /// Starts monitoring multiple asynchronous streams of information.
    private func startTracking() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await trackStatus() }
            group.addTask { await routeDataModel.trackVoiceGuidance() }
        }
    }
    
    /// Monitors the asynchronous stream of tracking statuses.
    ///
    /// When new statuses are delivered, update the route's traversed and remaining graphics.
    private func trackStatus() async {
        guard let routeTracker = routeDataModel.routeTracker else { return }
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

extension AugmentRealityToNavigateRouteView {
    @MainActor
    class RouteDataModel: ObservableObject {
        /// An AVSpeechSynthesizer for text to speech.
        let speechSynthesizer = AVSpeechSynthesizer()
        /// The route task that solves the route using the online routing service, using API key authentication.
        let routeTask = RouteTask(url: URL(string: "https://route-api.arcgis.com/arcgis/rest/services/World/Route/NAServer/Route_World")!)
        /// The parameters for route task to solve a route.
        var routeParameters = RouteParameters()
        /// The route tracker.
        @Published var routeTracker: RouteTracker?
        /// The route result.
        @Published var routeResult: RouteResult?
        
        /// Monitors the asynchronous stream of voice guidances.
        func trackVoiceGuidance() async {
            guard let routeTracker = routeTracker else { return }
            for try await voiceGuidance in routeTracker.voiceGuidances {
                speechSynthesizer.stopSpeaking(at: .word)
                speechSynthesizer.speak(AVSpeechUtterance(string: voiceGuidance.text))
            }
        }
    }
}
