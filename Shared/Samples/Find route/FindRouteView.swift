// Copyright 2022 Esri
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

struct FindRouteView: View {
    /// A Boolean value indicating whether to show the directions.
    @State private var isShowingDirections = false
    
    /// A Boolean value indicating whether to solve the route.
    @State private var isSolvingRoute = false
    
    /// The view model for this sample.
    @StateObject private var model = Model()
    
    var body: some View {
        MapView(map: model.map, graphicsOverlays: model.graphicsOverlays)
            .alert(isPresented: $model.isShowingAlert, presentingError: model.error)
            .task {
                await model.initializeRouteParameters()
            }
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Spacer()
                    Button("Route") {
                        isSolvingRoute = true
                    }
                    .disabled(model.isRouteDisabled || isSolvingRoute)
                    .task(id: isSolvingRoute) {
                        // Ensures that solving the route is true.
                        guard isSolvingRoute else { return }
                        // Finds the route.
                        await model.findRoute()
                        // Sets solving the route to false.
                        isSolvingRoute = false
                    }
                    Spacer()
                    Button {
                        isShowingDirections = true
                    } label: {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond")
                    }
                    .disabled(model.directions.isEmpty)
                    .popover(isPresented: $isShowingDirections) {
                        NavigationView {
                            List(model.directions, id: \.directionText) { directionManeuver in
                                Text(directionManeuver.directionText)
                            }
                            .navigationTitle("Directions")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button {
                                        isShowingDirections = false
                                    } label: {
                                        Text("Done")
                                            .bold()
                                    }
                                }
                            }
                        }
                        .navigationViewStyle(.stack)
                        .frame(minWidth: 320, minHeight: 390)
                    }
                }
            }
    }
}

private extension FindRouteView {
    /// A view model for this sample.
    @MainActor class Model: ObservableObject {
        /// The directions for the route.
        @Published var directions: [DirectionManeuver] = []
        
        /// The parameters for the route.
        @Published var routeParameters: RouteParameters!
        
        /// A Boolean value indicating whether to show an alert.
        @Published var isShowingAlert = false
        
        /// The error shown in the alert.
        @Published var error: Error?
        
        /// A Boolean value indicating whether to disable the route button.
        var isRouteDisabled: Bool { routeParameters == nil }
        
        /// The route task.
        private let routeTask = RouteTask(url: .routeTask)
        
        /// A map with a topographic basemap style and an initial viewpoint.
        let map: Map
        
        /// The stops for the route.
        private let stops: [Stop]
        
        /// The graphics overlay for the route.
        private let routeGraphicsOverlay: GraphicsOverlay
        
        /// The graphics overlay for the stops.
        private let stopGraphicsOverlay: GraphicsOverlay
        
        /// The graphics overlays for the route and stops.
        var graphicsOverlays: [GraphicsOverlay] { [routeGraphicsOverlay, stopGraphicsOverlay] }
        
        /// The graphic for the route.
        private var routeGraphic: Graphic { routeGraphicsOverlay.graphics.first! }
        /// The graphic for the first stop.
        private var stopOneGraphic: Graphic { stopGraphicsOverlay.graphics.first! }
        /// The graphic for the second stop.
        private var stopTwoGraphic: Graphic { stopGraphicsOverlay.graphics.last! }
        
        init() {
            // Initializes the map
            map = Map(basemapStyle: .arcGISTopographic)
            map.initialViewpoint = Viewpoint(
                center: Point(
                    x: -13041154.7153,
                    y: 3858170.2368,
                    spatialReference: .webMercator
                ),
                scale: 1e5
            )
            
            // Initializes the graphics overlay for the route.
            routeGraphicsOverlay = GraphicsOverlay(graphics: [
                Graphic(symbol: SimpleLineSymbol(style: .solid, color: .yellow, width: 5))
            ])
            
            // Initializes the stops and the graphics overlay for them.
            let stopOne = Stop.one
            let stopTwo = Stop.two
            stops = [stopOne, stopTwo]
            
            let stopOneGraphic = Graphic(
                geometry: stopOne.geometry,
                symbol: TextSymbol(text: stopOne.name, color: .blue, size: 20)
            )
            
            let stopTwoGraphic = Graphic(
                geometry: stopTwo.geometry,
                symbol: TextSymbol(text: stopTwo.name, color: .red, size: 20)
            )
            
            stopGraphicsOverlay = GraphicsOverlay(graphics: [stopOneGraphic, stopTwoGraphic])
        }
        
        /// Initializes the route parameters.
        func initializeRouteParameters() async {
            do {
                // Creates the default parameters.
                let parameters = try await routeTask.createDefaultParameters()
                
                // Sets the return directions on the parameters to true.
                parameters.returnDirections = true
                
                // Sets the stops for the route.
                parameters.setStops(stops)
                
                // Initializes the route parameters.
                routeParameters = parameters
            } catch {
                self.error = error
                isShowingAlert = true
            }
        }
        
        /// Finds the route from stop one to stop two.
        func findRoute() async {
            // Resets the route geometry and directions.
            routeGraphic.geometry = nil
            directions.removeAll()
            
            do {
                // Solves the route based on the route parameters.
                let routeResult = try await routeTask.solveRoute(routeParameters: routeParameters)
                if let firstRoute = routeResult.routes.first {
                    // Updates the route geometry and directions.
                    routeGraphic.geometry = firstRoute.routeGeometry
                    directions = firstRoute.directionManeuvers
                }
            } catch {
                self.error = error
                isShowingAlert = true
            }
        }
    }
}

private extension Stop {
    /// The stop for the origin.
    static var one: Stop {
        let stop = Stop(point: Point(x: -13041171.537945, y: 3860988.271378, spatialReference: .webMercator))
        stop.name = "Origin"
        return stop
    }
    /// The stop for the destination.
    static var two: Stop {
        let stop = Stop(point: Point(x: -13041693.562570, y: 3856006.859684, spatialReference: .webMercator))
        stop.name = "Destination"
        return stop
    }
}

private extension URL {
    /// The URL for the route task.
    static var routeTask: URL {
        URL(string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/NetworkAnalysis/SanDiego/NAServer/Route")!
    }
}
