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

extension AugmentRealityToNavigateRouteView {
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
        /// A Boolean value indicating whether a route is selected.
        @State private var didSelectRoute = false
        /// The error shown in the error alert.
        @State private var error: Error?
        
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
                            didSelectRoute = true
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
            .onChange(of: didSelectRoute) { didSelectRoute in
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
                    .disabled(!didSelectRoute)
                    Spacer()
                    Button {
                        model.reset()
                        statusText = "Tap to place a start point."
                    } label: {
                        Image(systemName: "trash")
                            .imageScale(.large)
                    }
                    .disabled(!didSelectRouteStop && !didSelectRoute)
                }
            }
            .onAppear {
                statusText = "Tap to place a start point."
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
        @ObservedObject var routeDataModel = AugmentRealityToNavigateRouteView.RouteDataModel()
        /// A map with an imagery basemap style.
        let map = Map(basemapStyle: .arcGISImagery)
        /// The data source to track device location and provide updates to route tracker.
        let locationDataSource = SystemLocationDataSource()
        /// The graphic (with solid yellow 3D tube symbol) to represent the route.
        let routeGraphic = Graphic()
        /// The map's location display.
        let locationDisplay: LocationDisplay = {
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
                let startStopGraphic = Graphic(geometry: startPoint, symbol: stopSymbol)
                stopGraphicsOverlay.addGraphic(startStopGraphic)
            }
        }
        /// A point representing the destination of navigation.
        var endPoint: Point? {
            didSet {
                let stopSymbol = PictureMarkerSymbol(image: UIImage(named: "StopB")!)
                let endStopGraphic = Graphic(geometry: endPoint, symbol: stopSymbol)
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
            routeDataModel.routeParameters.clearStops()
            startPoint = nil
            endPoint = nil
        }
    }
}
