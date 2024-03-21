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
import SwiftUI
import AVFoundation

struct AugmentRealityToNavigateRouteView: View {
    /// The data model for the selected route.
    @StateObject private var routeDataModel = RouteDataModel()
    /// An AVSpeechSynthesizer for text to speech.
    private let speechSynthesizer = AVSpeechSynthesizer()
    /// A Boolean value indicating whether the route planner is showing.
    @State private var isShowingRoutePlanner = true
    /// The location datasource that is used to access the device location.
    @State private var locationDataSource = SystemLocationDataSource()
    /// A scene with an imagery basemap.
    @State private var scene: ArcGIS.Scene = {
        let surface = Surface()
        surface.backgroundGrid.isVisible = false
        surface.navigationConstraint = .unconstrained
        let scene = Scene(basemapStyle: .arcGISImagery)
        scene.baseSurface = surface
        scene.baseSurface.opacity = 0.5
        return scene
    }()
    /// The elevation surface set to the base surface of the scene.
    @State private var elevationSurface: Surface = {
        let elevationSurface = Surface()
        elevationSurface.navigationConstraint = .unconstrained
        elevationSurface.opacity = 0.5
        elevationSurface.backgroundGrid.isVisible = false
        return elevationSurface
    }()
    /// The elevation source with elevation service URL.
    @State private var elevationSource: ElevationSource?
    /// The graphics overlay containing a graphic.
    @State private var graphicsOverlay = GraphicsOverlay()
    /// The status text displayed to the user.
    @State private var statusText = ""
    /// A Boolean value indicating whether the use is navigatig the route.
    @State private var isNavigating = false
    /// The result of the route selected in the route planner view.
    @State private var routeResult: RouteResult?
    /// The current location elevation in meters.
    @State private var elevation: Double?
    
    init() {
        let elevationSource = ArcGISTiledElevationSource(url: URL(string: "https://elevation3d.arcgis.com/arcgis/rest/services/WorldElevation3D/Terrain3D/ImageServer")!)
        elevationSurface.addElevationSource(elevationSource)
        Task { try await elevationSource.load() }
    }
    
    var body: some View {
        if isShowingRoutePlanner {
            RoutePlannerView(isShowing: $isShowingRoutePlanner)
                .onDidSelectRoute { routeGraphic, routeResult  in
                    self.routeResult = routeResult
                    graphicsOverlay = makeRouteOverlay(
                        for: routeResult,
                        using: routeGraphic
                    )
                }
        } else {
            WorldScaleSceneView { _ in
                SceneView(scene: scene, graphicsOverlays: [graphicsOverlay])
            }
            .calibrationButtonAlignment(.bottomLeading)
            .ignoresSafeArea(edges: [.horizontal, .bottom])
            .task {
                statusText = "Adjust calibration before starting."
                Task {
                    try await locationDataSource.start()
                    
                    for await location in locationDataSource.locations {
                        try await routeDataModel.routeTracker?.track(location)
                        self.elevation = location.position.z
                    }
                }
            }
            .overlay(alignment: .top) {
                Text(statusText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(8)
                    .background(.regularMaterial, ignoresSafeAreaEdges: .horizontal)
            }
            .overlay(alignment: .bottomTrailing) {
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
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .disabled(isNavigating)
                .padding()
                .padding(.vertical)
            }
            .ignoresSafeArea(edges: [.horizontal, .bottom])
            .onDisappear {
                Task { await locationDataSource.stop() }
            }
        }
    }
    
    /// Create a graphic overlay and adds a graphic (with solid yellow 3D tube symbol)
    /// to represent the route.
    @MainActor
    private func makeRouteOverlay(for routeResult: RouteResult, using routeGraphic: Graphic) -> GraphicsOverlay {
        let graphicsOverlay = GraphicsOverlay()
        graphicsOverlay.sceneProperties.surfacePlacement = .absolute
        let strokeSymbolLayer = SolidStrokeSymbolLayer(
            width: 1.0,
            color: .yellow,
            geometricEffects: [],
            lineStyle3D: .tube
        )
        let polylineSymbol = MultilayerPolylineSymbol(symbolLayers: [strokeSymbolLayer])
        let polylineRenderer = SimpleRenderer(symbol: polylineSymbol)
        graphicsOverlay.renderer = polylineRenderer
        
        if let originalPolyline = routeResult.routes.first?.geometry {
            let polyline = addElevationToPolyline(polyline: originalPolyline)
            routeGraphic.geometry = polyline
            graphicsOverlay.addGraphic(routeGraphic)
        }
        
        return graphicsOverlay
    }
    
    /// Densify the polyline geometry so the elevation can be adjusted every 0.3 meters,
    /// and add an elevation to the geometry.
    ///
    /// - Parameters:
    ///   - polyline: The polyline geometry of the route.
    ///   - z: A `Double` value representing z elevation.
    private func addElevationToPolyline(polyline: Polyline, elevation z: Double = 3) -> Polyline {
        if let densifiedPolyline = GeometryEngine.densify(polyline, maxSegmentLength: 0.3) as? Polyline {
            let polylinebuilder = PolylineBuilder(spatialReference: polyline.spatialReference)
            
            let allPoints = densifiedPolyline.parts.flatMap { $0.points }
            
            allPoints.forEach { point in
                let newPoint = GeometryEngine.makeGeometry(from: point, z: elevation ?? 0 + z)
                
                // Put the new point 3 meters above the ground elevation.
                polylinebuilder.add(newPoint)
            }
            return polylinebuilder.toGeometry()
        } else {
            return polyline
        }
    }
    
    /// Starts navigating the route.
    @MainActor
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
            group.addTask { await self.trackStatus() }
            group.addTask { await self.trackVoiceGuidance() }
        }
    }
    
    /// Monitors the asynchronous stream of tracking statuses.
    ///
    /// When new statuses are delivered, update the route's traversed and remaining graphics.
    private func trackStatus() async {
        guard let routeTracker = routeDataModel.routeTracker else { return }
        for await status in routeTracker.$trackingStatus {
            if let status {
                switch status.destinationStatus {
                case .notReached, .approaching:
                    guard let route = routeResult?.routes.first else { return }
                    let currentManeuver = route.directionManeuvers[status.currentManeuverIndex]
                    statusText = currentManeuver.text
                case .reached:
                    statusText = "You have arrived!"
                @unknown default:
                    break
                }
            }
        }
    }
    
    /// Monitors the asynchronous stream of voice guidances.
    private func trackVoiceGuidance() async {
        guard let routeTracker = routeDataModel.routeTracker else { return }
        for try await voiceGuidance in routeTracker.voiceGuidances {
            speechSynthesizer.stopSpeaking(at: .word)
            speechSynthesizer.speak(AVSpeechUtterance(string: voiceGuidance.text))
        }
    }
}

extension AugmentRealityToNavigateRouteView {
    @MainActor
    class RouteDataModel: ObservableObject {
        /// The route task that solves the route using the online routing service, using API key authentication.
        @Published var routeTask = RouteTask(url: URL(string: "https://route-api.arcgis.com/arcgis/rest/services/World/Route/NAServer/Route_World")!)
        /// The parameters for route task to solve a route.
        @Published var routeParameters = RouteParameters()
        /// The route tracker.
        @Published var routeTracker: RouteTracker?
        /// The route result.
        @Published var routeResult: RouteResult?
    }
}
