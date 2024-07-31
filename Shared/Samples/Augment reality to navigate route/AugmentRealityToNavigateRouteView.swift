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
import CoreLocation
import SwiftUI

@MainActor
struct AugmentRealityToNavigateRouteView: View {
    /// The view model for the map view in the sample.
    @StateObject private var model = MapModel()
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    /// The point on the map where the user tapped.
    @State private var tapLocation: Point?
    
    var body: some View {
        MapView(
            map: model.map,
            graphicsOverlays: model.graphicsOverlays
        )
        .locationDisplay(model.locationDisplay)
        .onSingleTapGesture { _, mapPoint in
            tapLocation = mapPoint
        }
        .task(id: tapLocation) {
            guard let tapLocation else { return }
            
            do {
                try await model.addRouteGraphic(for: tapLocation)
            } catch {
                self.error = error
            }
        }
        .task {
            do {
                try await model.setUp()
            } catch {
                self.error = error
            }
        }
        .overlay(alignment: .top) {
            instructionText
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                toolbarButtons
            }
        }
        .onAppear {
            model.statusText = "Tap to place a start point."
        }
        .errorAlert(presentingError: $error)
    }
    
    /// The buttons in the bottom toolbar.
    @ViewBuilder private var toolbarButtons: some View {
        Spacer()
        NavigationLink {
            ARRouteSceneView(model: model.sceneModel)
        } label: {
            Image(systemName: "camera")
                .imageScale(.large)
        }
        .disabled(!model.didSelectRoute)
        
        Spacer()
        Button {
            model.reset()
            model.statusText = "Tap to place a start point."
        } label: {
            Image(systemName: "trash")
                .imageScale(.large)
        }
        .disabled(!model.didSelectRouteStop && !model.didSelectRoute)
    }
    
    /// The instruction text in the overlay.
    private var instructionText: some View {
        Text(model.statusText)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(8)
            .background(.thinMaterial, ignoresSafeAreaEdges: .horizontal)
    }
}

private extension AugmentRealityToNavigateRouteView {
    // MARK: Map Model
    
    /// A view model for this example.
    @MainActor
    class MapModel: ObservableObject {
        /// A map with an imagery basemap style.
        let map = Map(basemapStyle: .arcGISImagery)
        
        /// The map's location display.
        let locationDisplay: LocationDisplay = {
            let locationDisplay = LocationDisplay()
            locationDisplay.autoPanMode = .recenter
            return locationDisplay
        }()
        
        /// The graphics overlay for the stops.
        private let stopGraphicsOverlay = GraphicsOverlay()
        
        /// A graphics overlay for route graphics.
        private let routeGraphicsOverlay: GraphicsOverlay = {
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
        private var startPoint: Point? {
            didSet {
                let stopSymbol = PictureMarkerSymbol(image: .stopA)
                let startStopGraphic = Graphic(geometry: startPoint, symbol: stopSymbol)
                stopGraphicsOverlay.addGraphic(startStopGraphic)
            }
        }
        
        /// A point representing the destination of navigation.
        private var endPoint: Point? {
            didSet {
                let stopSymbol = PictureMarkerSymbol(image: .stopB)
                let endStopGraphic = Graphic(geometry: endPoint, symbol: stopSymbol)
                stopGraphicsOverlay.addGraphic(endStopGraphic)
            }
        }
        
        /// A Boolean value indicating whether a route stop is selected.
        var didSelectRouteStop: Bool {
            startPoint != nil || endPoint != nil
        }
        
        /// A Boolean value indicating whether a route is selected.
        var didSelectRoute: Bool {
            startPoint != nil && endPoint != nil
        }
        
        /// The view model for scene view in the sample.
        let sceneModel = SceneModel()
        
        /// The status text displayed to the user.
        @Published var statusText = ""
        
        deinit {
            Task {
                /// Stop the location data source.
                await locationDisplay.dataSource.stop()
            }
        }
        
        /// Performs important tasks including setting up the location display, creating route parameters,
        /// and loading the scene elevation source.
        func setUp() async throws {
            try await startLocationDisplay()
            try await makeParameters()
            try await sceneModel.loadElevationSource()
        }
        
        /// Starts the location display to show user's location on the map.
        func startLocationDisplay() async throws {
            // Request location permission if it has not yet been determined.
            let locationManager = CLLocationManager()
            if locationManager.authorizationStatus == .notDetermined {
                locationManager.requestWhenInUseAuthorization()
            }
            
            locationDisplay.dataSource = sceneModel.locationDataSource
            
            // Start the location display to zoom to the user's current location.
            try await locationDisplay.dataSource.start()
        }
        
        /// Creates walking route parameters.
        func makeParameters() async throws {
            let parameters = try await sceneModel.routeTask.makeDefaultParameters()
            
            if let walkMode = sceneModel.routeTask.info.travelModes.first(where: { $0.name.contains("Walking") }) {
                parameters.travelMode = walkMode
                parameters.returnsStops = true
                parameters.returnsDirections = true
                parameters.returnsRoutes = true
                sceneModel.routeParameters = parameters
            }
        }
        
        /// Adds a route graphic for the selected route using a given start and end point.
        /// - Parameter mapPoint: The map point for the route start or end point.
        func addRouteGraphic(for mapPoint: Point) async throws {
            if startPoint == nil {
                startPoint = mapPoint
                statusText = "Tap to place destination."
            } else if endPoint == nil {
                endPoint = mapPoint
                sceneModel.routeParameters.setStops(makeStops())
                
                let routeResult = try await sceneModel.routeTask.solveRoute(
                    using: sceneModel.routeParameters
                )
                if let firstRoute = routeResult.routes.first {
                    let routeGraphic = Graphic(geometry: firstRoute.geometry)
                    routeGraphicsOverlay.addGraphic(routeGraphic)
                    sceneModel.routeResult = routeResult
                    try await sceneModel.makeRouteOverlay()
                    statusText = "Tap camera to start navigation."
                }
            }
        }
        
        /// Creates the start and destination stops for the navigation.
        private func makeStops() -> [Stop] {
            guard let startPoint, let endPoint else { return [] }
            let stop1 = Stop(point: startPoint)
            stop1.name = "Start"
            let stop2 = Stop(point: endPoint)
            stop2.name = "Destination"
            return [stop1, stop2]
        }
        
        /// Resets the start and destination stops for the navigation.
        func reset() {
            routeGraphicsOverlay.removeAllGraphics()
            stopGraphicsOverlay.removeAllGraphics()
            sceneModel.routeParameters.clearStops()
            startPoint = nil
            endPoint = nil
        }
    }
}
