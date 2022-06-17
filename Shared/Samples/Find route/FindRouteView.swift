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

import SwiftUI
import ArcGIS

struct FindRouteView: View {
    /// The direction maneuvers for the calculated route.
    @State private var directionsList: [DirectionManeuver] = []
    
    /// The parameters for the route.
    @State private var routeParameters: RouteParameters?
    
    /// A map with a topographic basemap style and an initial viewpoint.
    @StateObject private var map: Map = {
        let map = Map(basemapStyle: .arcGISTopographic)
        map.initialViewpoint = Viewpoint(
            center: Point(
                x: -13041154.715252,
                y: 3858170.236806,
                spatialReference: .webMercator
            ),
            scale: 1e5
        )
        return map
    }()
    
    /// The graphics overlay for the stops.
    @StateObject private var stopGraphicsOverlay: GraphicsOverlay = {
        let stopOne = Stop.stopOne
        let stopTwo = Stop.stopTwo
        
        let stopOneGraphic = Graphic(
            geometry: stopOne.geometry,
            symbol: TextSymbol(text: stopOne.name, color: .blue, size: 20)
        )
        let stopTwoGraphic = Graphic(
            geometry: stopTwo.geometry,
            symbol: TextSymbol(text: stopTwo.name, color: .red, size: 20)
        )
        
        return GraphicsOverlay(graphics: [stopOneGraphic, stopTwoGraphic])
    }()
    
    /// The graphics overlay for the route.
    @StateObject private var routeGraphicsOverlay: GraphicsOverlay = {
        return GraphicsOverlay(
            graphics: [
                Graphic(symbol: SimpleLineSymbol(style: .solid, color: .yellow, width: 5))
            ]
        )
    }()
    
    /// A route task from a URL
    private let routeTask = RouteTask(url: .routeTaskURL)
    
    /// The stops for this sample.
    private let stops: [Stop] = [.stopOne, .stopTwo]
    
    /// The graphic for the first stop.
    private var stopOneGraphic: Graphic { stopGraphicsOverlay.graphics.first! }
    
    /// The graphic for the second stop.
    private var stopTwoGraphic: Graphic { stopGraphicsOverlay.graphics.last! }
    
    /// The graphic for the route.
    private var routeGraphic: Graphic { routeGraphicsOverlay.graphics.first! }
    
    /// Creates the parameters for the route.
    private func createRouteParameters() async {
        // Creates the default parameters.
        let parameters = try? await routeTask.createDefaultParameters()
        
        // Sets return directions on the parameters to true.
        parameters?.returnDirections = true
        
        // Updates the parameters for the route.
        routeParameters = parameters
    }
    
    /// Finds the route from stop one to stop two.
    private func findRoute() async {
        // Ensures the route parameters exist.
        guard let routeParameters = routeParameters else { return }
        
        // Resets the geometry, directions, and stops.
        routeGraphic.geometry = nil
        directionsList.removeAll()
        routeParameters.clearStops()
        
        // Sets the stops for the route parameters.
        routeParameters.setStops(stops)
        
        // Solves the route based on the given route parameters.
        let routeResult = try? await routeTask.solveRoute(routeParameters: routeParameters)
        if let firstRoute = routeResult?.routes.first {
            // Updates the route geometry and list of directions.
            routeGraphic.geometry = firstRoute.routeGeometry
            directionsList = firstRoute.directionManeuvers
        }
    }
    
    var body: some View {
        MapView(map: map, graphicsOverlays: [routeGraphicsOverlay, stopGraphicsOverlay])
            .task {
                await createRouteParameters()
            }
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Spacer()
                    Button("Route") {
                        Task {
                            await findRoute()
                        }
                    }
                    Spacer()
                    NavigationLink {
                        // Displays the list of direction maneuvers.
                        List {
                            ForEach(0..<directionsList.count, id: \.self) { index in
                                Text(directionsList[index].directionText)
                            }
                        }
                        .navigationTitle("Directions")
                    } label: {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond")
                    }
                    .disabled(directionsList.isEmpty)
                }
            }
    }
}

private extension Stop {
    /// The stop for the origin.
    static var stopOne: Stop {
        let stop = Stop(point: Point(x: -13041171.537945, y: 3860988.271378, spatialReference: .webMercator))
        stop.name = "Origin"
        return stop
    }
    
    /// The stop for the destination.
    static var stopTwo: Stop {
        let stop = Stop(point: Point(x: -13041693.562570, y: 3856006.859684, spatialReference: .webMercator))
        stop.name = "Destination"
        return stop
    }
}

private extension URL {
    /// The URL for the route task.
    static var routeTaskURL: URL {
        URL(string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/NetworkAnalysis/SanDiego/NAServer/Route")!
    }
}
