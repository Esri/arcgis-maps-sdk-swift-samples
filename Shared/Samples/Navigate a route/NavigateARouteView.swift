// Copyright 2023 Esri
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
import AVFoundation
import SwiftUI

struct NavigateARouteView: View {
    /// A Boolean value indicating whether the sample is navigating the route.
    @State private var isNavigatingRoute = false
    
    /// A Boolean value indicating whether navigation is being reset.
    @State private var isResettingRoute = false
    
    /// The view model for this sample.
    @StateObject private var model = Model()
    
    var body: some View {
        MapView(
            map: model.map,
            viewpoint: model.viewpoint,
            graphicsOverlays: model.graphicsOverlays
        )
        .onViewpointChanged(kind: .centerAndScale) { model.viewpoint = $0 }
        .locationDisplay(model.locationDisplay)
        .task {
            // Solves the route and sets the navigation.
            await model.solveRoute()
            model.setNavigation()
            await model.startUpdates()
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button("Navigate") {
                    isNavigatingRoute = true
                }
                .task(id: isNavigatingRoute) {
                    guard isNavigatingRoute else { return }
                    await model.startNavigation()
                }
                .disabled(model.isNavigateDisabled || isNavigatingRoute)
                
                Spacer()
                
                Button("Recenter") {
                    model.autoPanMode = .navigation
                }
                .disabled(!isNavigatingRoute || model.autoPanMode == .navigation)
                
                Spacer()
                
                Button("Reset") {
                    isResettingRoute = true
                }
                .task(id: isResettingRoute) {
                    guard isResettingRoute else { return }
                    await model.resetNavigation()
                    isNavigatingRoute = false
                    isResettingRoute = false
                }
                .disabled(isResettingRoute)
            }
        }
    }
}

private extension NavigateARouteView {
    /// A view model for this sample.
    @MainActor
    class Model: ObservableObject {
        /// A Boolean value indicating whether the navigate button is disabled.
        @Published var isNavigateDisabled = true
        
        /// A Boolean value indicating whether to show an alert.
        @Published var isShowingAlert = false
        
        /// The error shown in the alert.
        @Published var error: Error?
        
        /// The viewpoint of the map.
        @Published var viewpoint: Viewpoint?
        
        /// The current auto-pan mode.
        @Published var autoPanMode: LocationDisplay.AutoPanMode {
            didSet {
                locationDisplay.autoPanMode = autoPanMode
            }
        }
        
        /// A map with a navigation basemap style.
        let map = Map(basemapStyle: .arcGISNavigation)
        
        /// The map's location display.
        let locationDisplay = LocationDisplay()
        
        /// The route task.
        private let routeTask = RouteTask(url: .routeTask)
        
        /// The route result.
        private var routeResult: RouteResult!
        
        /// The route tracker.
        private var routeTracker: RouteTracker!
        
        /// The directions for the route.
        private var directions: [DirectionManeuver] = []
        
        /// The graphics overlay for the stops.
        private let stopGraphicsOverlay: GraphicsOverlay
        
        /// The graphics overlay for the route.
        private let routeGraphicsOverlay: GraphicsOverlay
        
        /// The map's graphics overlays.
        var graphicsOverlays: [GraphicsOverlay] {
            return [stopGraphicsOverlay, routeGraphicsOverlay]
        }
        
        /// A graphic of the route ahead.
        private var routeAheadGraphic: Graphic { routeGraphicsOverlay.graphics.first! }
        
        /// A graphic of the route traversed.
        private var routeTraversedGraphic: Graphic { routeGraphicsOverlay.graphics.last! }
        
        init() {
            autoPanMode = .off
            
            // Creates the graphics for each stop.
            let stopGraphics = stops.map {
                Graphic(
                    geometry: $0.geometry,
                    symbol: SimpleMarkerSymbol(style: .diamond, color: .orange, size: 20)
                )
            }
            
            // Creates the graphics for the route ahead and traversed.
            let routeAheadGraphic = Graphic(symbol: SimpleLineSymbol(style: .dash, color: .systemPurple, width: 5))
            let routeTraversedGraphic = Graphic(symbol: SimpleLineSymbol(style: .solid, color: .systemBlue, width: 3))
            
            // Creates the graphics overlay for the stops and route.
            stopGraphicsOverlay = GraphicsOverlay(graphics: stopGraphics)
            routeGraphicsOverlay = GraphicsOverlay(graphics: [routeAheadGraphic, routeTraversedGraphic])
        }
        
        /// Solves the route.
        func solveRoute() async {
            do {
                // Creates the default parameters from the route task.
                let parameters = try await routeTask.makeDefaultParameters()
                
                // Configures the parameters.
                parameters.returnsDirections = true
                parameters.returnsStops = true
                parameters.returnsRoutes = true
                parameters.outputSpatialReference = .wgs84
                
                // Sets the stops on the parameters.
                parameters.setStops(stops)
                
                // Solves the route based on the parameters.
                routeResult = try await routeTask.solveRoute(using: parameters)
                
                // Enables the navigate button.
                isNavigateDisabled = false
            } catch {
                self.error = error
                isShowingAlert = true
            }
        }
        
        /// Sets the route tracker and location display's data source with a solved route. Updates the list of
        /// directions, the route ahead graphic, and the map's viewpoint.
        func setNavigation() {
            // Creates a route tracker from the route results.
            routeTracker = RouteTracker(routeResult: routeResult, routeIndex: 0, skipsCoincidentStops: true)
            routeTracker.voiceGuidanceUnitSystem = Locale.current.usesMetricSystem ? .metric : .imperial
            
            // Gets the route and its geometry from the route result.
            guard let firstRoute = routeResult.routes.first,
                  let routeGeometry = firstRoute.geometry else {
                return
            }
            
            // Updates the directions.
            directions = firstRoute.directionManeuvers
            
            // Creates the mock data source from the route's geometry.
            let densifiedRoute = GeometryEngine.geodeticDensify(
                routeGeometry,
                maxSegmentLength: 50,
                lengthUnit: .meters,
                curveType: .geodesic
            ) as! Polyline
            let mockDataSource = SimulatedLocationDataSource(polyline: densifiedRoute)
            
            // Creates a route tracker location data source.
            let routeTrackerLocationDataSource = RouteTrackerLocationDataSource(
                routeTracker: routeTracker,
                locationDataSource: mockDataSource
            )
            
            // Sets the location display's data source.
            locationDisplay.dataSource = routeTrackerLocationDataSource
            
            // Updates the graphics and viewpoint.
            routeAheadGraphic.geometry = routeGeometry
            viewpoint = Viewpoint(boundingGeometry: routeGeometry)
        }
        
        func startUpdates() async {
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    await self.updateAutoPanMode()
                }
            }
        }
        
        /// Updates the current auto-pan mode if it does not match the location display's auto-pan mode.
        private func updateAutoPanMode() async {
            for await mode in locationDisplay.$autoPanMode {
                if autoPanMode != mode {
                    autoPanMode = mode
                }
            }
        }
        
        /// Starts navigating the route.
        func startNavigation() async {
            do {
                try await locationDisplay.dataSource.start()
                locationDisplay.autoPanMode = .navigation
            } catch {
                self.error = error
                isShowingAlert = true
            }
        }
        
        func resetNavigation() async {
            locationDisplay.autoPanMode = .off
            await locationDisplay.dataSource.stop()
            setNavigation()
        }
    }
    
    /// The stops for this sample.
    static var stops: [Stop] {
        let one = Stop(point: Point(x: -117.160386727, y: 32.706608, spatialReference: .wgs84))
        one.name = "San Diego Convention Center"
        let two = Stop(point: Point(x: -117.173034, y: 32.712329, spatialReference: .wgs84))
        two.name = "USS San Diego Memorial"
        let three = Stop(point: Point(x: -117.147230, y: 32.730467, spatialReference: .wgs84))
        three.name = "RH Fleet Aerospace Museum"
        return [one, two, three]
    }
}

private extension URL {
    /// The URL for the route task.
    static var routeTask: URL {
        URL(string: "http://sampleserver7.arcgisonline.com/server/rest/services/NetworkAnalysis/SanDiego/NAServer/Route")!
    }
}
