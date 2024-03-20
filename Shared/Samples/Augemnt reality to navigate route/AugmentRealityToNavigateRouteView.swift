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
import CoreLocation
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
    @State var elevationSurface: Surface = {
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
            VStack {
                WorldScaleSceneView { proxy in
                    SceneView(scene: scene, graphicsOverlays: [graphicsOverlay])
                }
                .calibrationButtonAlignment(.bottomLeading)
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
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .padding()
                .padding([.bottom, .trailing], 10)
                .disabled(isNavigating)
            }
            .onDisappear {
                Task { await locationDataSource.stop() }
            }
        }
    }
    
    /// Create a graphic overlay and adds a graphic (with solid yellow 3D tube symbol)
    /// to represent the route.
    @MainActor
    func makeRouteOverlay(for routeResult: RouteResult, using routeGraphic: Graphic) -> GraphicsOverlay {
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
        
        Task {
            if let originalPolyline = routeResult.routes.first?.geometry {
                addElevationToPolyline(polyline: originalPolyline) { polyline in
                    routeGraphic.geometry = polyline
                    graphicsOverlay.addGraphic(routeGraphic)
                }
            }
        }
        
        return graphicsOverlay
    }
    
    /// Densify the polyline geometry so the elevation can be adjusted every 0.3 meters,
    /// and add an elevation to the geometry.
    ///
    /// - Parameters:
    ///   - polyline: The polyline geometry of the route.
    ///   - z: A `Double` value representing z elevation.
    ///   - completion: A completion closure to execute after the polyline is generated with success or not.
    func addElevationToPolyline(
        polyline: Polyline,
        elevation z: Double = 3,
        completion: @escaping (Polyline?) -> Void
    ) {
        if let densifiedPolyline = GeometryEngine.densify(polyline, maxSegmentLength: 0.3) as? Polyline {
            let polylinebuilder = PolylineBuilder(spatialReference: polyline.spatialReference)
            
            let allPoints = densifiedPolyline.parts.flatMap { $0.points }
            
            allPoints.forEach { point in
                let newPoint = GeometryEngine.makeGeometry(from: point, z: elevation ?? 0 + z)
                
                // Put the new point 3 meters above the ground elevation.
                polylinebuilder.add(newPoint)
            }
            completion(polylinebuilder.toGeometry())
        } else {
            completion(polyline)
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

private extension AugmentRealityToNavigateRouteView {
    @MainActor
    struct RoutePlannerView: View {
        /// The view model for this sample.
        @StateObject private var model = Model()
        /// A Boolean value indicating whether the view is showing.
        @Binding var isShowing: Bool
        /// The status text displayed to the user.
        @State private var statusText = ""
        /// User defined action to be performed when the slider delta value changes.
        var selectRouteAction: ((Graphic, RouteResult) -> Void)?
        /// A Boolean value indicating whether a route stop is selected.
        var didSelectRouteStop: Bool {
            model.startPoint != nil || model.endPoint != nil
        }
        /// The error shown in the error alert.
        @State var error: Error?
        
        var body: some View {
            MapView(
                map: model.map,
                graphicsOverlays: model.graphicsOverlays
            )
            .onSingleTapGesture { _, mapPoint in
                if model.startPoint == nil {
                    model.startPoint = mapPoint
                    statusText = "Tap to place destination."
                } else if model.endPoint == nil {
                    model.endPoint = mapPoint
                    model.routeDataModel.routeParameters.setStops(model.makeStops())
                    Task {
                        let routeResult = try await model.routeDataModel.routeTask.solveRoute(
                            using: model.routeDataModel.routeParameters
                        )
                        if let firstRoute = routeResult.routes.first {
                            let routeGraphic = Graphic(geometry: firstRoute.geometry)
                            model.routeGraphicsOverlay.addGraphic(routeGraphic)
                            model.routeDataModel.routeResult = routeResult
                            model.didSelectRoute = true
                            statusText = "Tap camera to start navigation."
                        } else {
                            self.error = error
                        }
                    }
                }
            }
            .locationDisplay(model.locationDisplay)
            .overlay(alignment: .top) {
                Text(statusText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(8)
                    .background(.regularMaterial, ignoresSafeAreaEdges: .horizontal)
            }
            .task {
                statusText = "Tap to place a start point."
            }
            .onChange(of: model.didSelectRoute) { didSelectRoute in
                guard didSelectRoute else { return }
                if let onDidSelectRoute = selectRouteAction,
                   let routeResult = model.routeDataModel.routeResult {
                    onDidSelectRoute(model.routeGraphic, routeResult)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Spacer()
                    Button {
                        isShowing = false
                    } label: {
                        Image(systemName: "camera")
                            .imageScale(.large)
                    }
                    .disabled(!model.didSelectRoute)
                    Spacer()
                    Button {
                        model.reset()
                        statusText = "Tap to place a start point."
                        model.didSelectRoute = false
                    } label: {
                        Image(systemName: "trash")
                            .imageScale(.large)
                    }
                    .disabled(!didSelectRouteStop)
                }
            }
            .onDisappear {
                Task { await model.locationDataSource.stop() }
            }
        }
        
        /// Sets an action to perform when the route is selected
        /// - Parameter action: The action to perform when the route is selected.
        func onDidSelectRoute(
            perform action: @escaping (Graphic, RouteResult) -> Void
        ) -> RoutePlannerView {
            var copy = self
            copy.selectRouteAction = action
            return copy
        }
    }
}

private extension AugmentRealityToNavigateRouteView.RoutePlannerView {
    /// A view model for this example.
    @MainActor
    class Model: ObservableObject {
        /// The data model for the selected route.
        @ObservedObject var routeDataModel = RouteDataModel()
        /// A map with an imagery basemap style.
        @Published var map: Map = {
            let map = Map(basemapStyle: .arcGISImagery)
            return map
        }()
        /// A binding to a Boolean value indicating whether a route is selected.
        @Published var didSelectRoute = false
        /// The graphics overlay for the route.
        @Published var routeOverlay: GraphicsOverlay = {
            let graphicsOverlay = GraphicsOverlay()
            graphicsOverlay.sceneProperties.surfacePlacement = .absolute
            let strokeSymbolLayer = SolidStrokeSymbolLayer(
                width: 1,
                color: .yellow,
                lineStyle3D: .tube
            )
            let polylineSymbol = MultilayerPolylineSymbol(symbolLayers: [strokeSymbolLayer])
            let polylineRenderer = SimpleRenderer(symbol: polylineSymbol)
            graphicsOverlay.renderer = polylineRenderer
            
            return graphicsOverlay
        }()
        /// The data source to track device location and provide updates to route tracker.
        let locationDataSource = SystemLocationDataSource()
        /// The graphic (with solid yellow 3D tube symbol) to represent the route.
        @Published var routeGraphic = Graphic()
        /// The map's location display.
        @Published var locationDisplay: LocationDisplay = {
            let locationDisplay = LocationDisplay()
            locationDisplay.autoPanMode = .recenter
            return locationDisplay
        }()
        /// The graphics overlay for the stops.
        let stopGraphicsOverlay = GraphicsOverlay()
        /// A graphic overlay for route graphics.
        let routeGraphicsOverlay: GraphicsOverlay = {
            let overlay = GraphicsOverlay()
            overlay.renderer = SimpleRenderer(
                symbol: SimpleLineSymbol(style: .solid, color: .yellow, width: 5)
            )
            return overlay
        }()
        /// The map's graphics overlays.
        var graphicsOverlays: [GraphicsOverlay] {
            return [stopGraphicsOverlay, routeGraphicsOverlay]
        }
        /// A point representing the start of navigation.
        var startPoint: Point? {
            didSet {
                let stopSymbol = PictureMarkerSymbol(image: UIImage(named: "StopA")!)
                let startStopGraphic = Graphic(geometry: self.startPoint, symbol: stopSymbol)
                stopGraphicsOverlay.addGraphic(startStopGraphic)
            }
        }
        /// A point representing the destination of navigation.
        var endPoint: Point? {
            didSet {
                let stopSymbol = PictureMarkerSymbol(image: UIImage(named: "StopB")!)
                let endStopGraphic = Graphic(geometry: self.endPoint, symbol: stopSymbol)
                stopGraphicsOverlay.addGraphic(endStopGraphic)
            }
        }
        
        init() {
            // Request when-in-use location authorization.
            let locationManager = CLLocationManager()
            if locationManager.authorizationStatus == .notDetermined {
                locationManager.requestWhenInUseAuthorization()
            }
            
            locationDisplay.dataSource = locationDataSource
            
            Task {
                try await locationDataSource.start()
                
                let parameters = try await routeDataModel.routeTask.makeDefaultParameters()
                
                if let walkMode = routeDataModel.routeTask.info.travelModes.first(where: { $0.name.contains("Walking") }) {
                    parameters.travelMode = walkMode
                    parameters.returnsStops = true
                    parameters.returnsDirections = true
                    parameters.returnsRoutes = true
                    routeDataModel.routeParameters = parameters
                }
            }
        }
        
        /// Creates the start and destination stops for the navigation.
        func makeStops() -> [Stop] {
            let stop1 = Stop(point: self.startPoint!)
            stop1.name = "Start"
            let stop2 = Stop(point: self.endPoint!)
            stop2.name = "Destination"
            return [stop1, stop2]
        }
        
        /// Resets the start and destination stops for the navigation.
        func reset() {
            routeGraphicsOverlay.removeAllGraphics()
            stopGraphicsOverlay.removeAllGraphics()
            routeDataModel.routeParameters.clearStops()
            startPoint = nil
            endPoint = nil
        }
    }
}

@MainActor
private class RouteDataModel: ObservableObject {
    /// The route task that solves the route using the online routing service, using API key authentication.
    @Published var routeTask = RouteTask(url: URL(string: "https://route-api.arcgis.com/arcgis/rest/services/World/Route/NAServer/Route_World")!)
    /// The parameters for route task to solve a route.
    @Published var routeParameters = RouteParameters()
    /// The route tracker.
    @Published var routeTracker: RouteTracker?
    /// The route result.
    @Published var routeResult: RouteResult?
}
