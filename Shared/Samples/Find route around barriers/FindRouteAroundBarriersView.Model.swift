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
import SwiftUI

extension FindRouteAroundBarriersView {
    /// The view model for the sample.
    @MainActor
    class Model: ObservableObject {
        // MARK: Properties
        
        /// A map with a topographic basemap cantered on San Diego, CA, USA.
        let map = {
            let map = Map(basemapStyle: .arcGISTopographic)
            map.initialViewpoint = Viewpoint(
                center: Point(x: -13_042_200, y: 3_857_900, spatialReference: .webMercator),
                scale: 1e5
            )
            return map
        }()
        
        /// The graphics overlays for the sample.
        let graphicsOverlays: [GraphicsOverlay]
        
        /// The graphics overlay for the stop graphics.
        private let stopGraphicsOverlay = GraphicsOverlay()
        
        /// The graphics overlay for the barrier graphics.
        private let barrierGraphicsOverlay = GraphicsOverlay()
        
        /// The graphics overlay for the route graphics.
        private let routeGraphicsOverlay = GraphicsOverlay()
        
        /// The blue marker symbol for the stop graphics.
        private let stopSymbol = {
            let markerImage = UIImage(named: "BlueMarker")!
            let markerSymbol = PictureMarkerSymbol(image: markerImage)
            markerSymbol.offsetY = markerImage.size.height / 2
            return markerSymbol
        }()
        
        /// The yellow line graphic for the route.
        private let routeGraphic = Graphic(
            symbol: SimpleLineSymbol(style: .solid, color: .yellow, width: 5)
        )
        
        /// The dashed orange line graphic for the direction route.
        let directionGraphic = Graphic(
            symbol: SimpleLineSymbol(style: .dashDot, color: .orange, width: 5)
        )
        
        /// The route task for routing.
        let routeTask = RouteTask(url: .sanDiegoNetworkAnalysis)
        
        /// The route parameters for routing with the route task.
        var routeParameters = RouteParameters()
        
        /// The resulting route from a routing operation with the route task.
        private(set) var route: Route?
        
        /// The text with the time and distance of the current route.
        @Published private(set) var routeInfoText = ""
        
        /// The count of stops currently on the map.
        @Published private(set) var stopsCount = 0
        
        /// The count of barriers currently on the map.
        @Published private(set) var barriersCount = 0
        
        init() {
            routeGraphicsOverlay.addGraphics([routeGraphic, directionGraphic])
            graphicsOverlays = [routeGraphicsOverlay, barrierGraphicsOverlay, stopGraphicsOverlay]
            updateRouteInfoText()
        }
        
        // MARK: Methods
        
        /// Adds a stop graphic to the map.
        /// - Parameter point: The point to add the stop graphic at.
        func addStopGraphic(at point: Point) {
            // Create a text symbol with the next index.
            let textSymbol = TextSymbol(
                text: "\(stopsCount + 1)",
                color: .white,
                size: 20,
                horizontalAlignment: .center,
                verticalAlignment: .middle
            )
            textSymbol.offsetY = stopSymbol.offsetY
            
            // Create a graphic with the marker symbol and text symbol.
            let compositeSymbol = CompositeSymbol(symbols: [stopSymbol, textSymbol])
            let stopGraphic = Graphic(geometry: point, symbol: compositeSymbol)
            
            // Add the new graphic to the stop graphics overlay.
            stopGraphicsOverlay.addGraphic(stopGraphic)
            stopsCount += 1
        }
        
        /// Adds a barrier graphic to the map.
        /// - Parameter point: The point to add the barrier graphic at.
        func addBarrierGraphic(at point: Point) {
            // Buffer the point and create the barrier symbol.
            let bufferedGeometry = GeometryEngine.buffer(around: point, distance: 500)
            let barrierSymbol = SimpleFillSymbol(style: .diagonalCross, color: .red)
            
            // Create a graphic from the symbol and buffer and add it to the graphics overlay.
            let barrierGraphic = Graphic(geometry: bufferedGeometry, symbol: barrierSymbol)
            barrierGraphicsOverlay.addGraphic(barrierGraphic)
            barriersCount += 1
        }
        
        /// Resets all the features on the map associated with a given feature type.
        /// - Parameter features: The features to remove from the map.
        func reset(features: RouteFeatures) {
            if features == .stops {
                // Reset the stops.
                stopGraphicsOverlay.removeAllGraphics()
                stopsCount = 0
                
                // Reset the route.
                route = nil
                routeGraphic.geometry = nil
                directionGraphic.geometry = nil
                updateRouteInfoText()
            } else {
                barrierGraphicsOverlay.removeAllGraphics()
                barriersCount = 0
            }
        }
        
        /// Routes using the route parameters and the current stops and barriers on the map.
        func route() async throws {
            // Update the route parameters' stops using the stop graphics.
            routeParameters.setStops(
                stopGraphicsOverlay.graphics
                    .compactMap { $0.geometry as? Point }
                    .map(Stop.init(point:))
            )
            
            // Update the route parameters' barriers using the barrier graphics.
            routeParameters.setPolygonBarriers(
                barrierGraphicsOverlay.graphics
                    .compactMap { $0.geometry as? ArcGIS.Polygon }
                    .map(PolygonBarrier.init(polygon:))
            )
            
            // Get the route from the route task using the updated route parameters.
            let routeResult = try await routeTask.solveRoute(using: routeParameters)
            guard let route = routeResult.routes.first else { return }
            
            // Update the route's associated properties.
            self.route = route
            directionGraphic.geometry = nil
            routeGraphic.geometry = route.geometry
            updateRouteInfoText()
        }
        
        /// Updates the route info text using the current route.
        private func updateRouteInfoText() {
            guard let route else {
                routeInfoText = "Tap to add a stop or barrier."
                return
            }
            
            // Format the route's time.
            let dateInterval = DateInterval(start: .now, duration: route.totalTime)
            let dateRange = dateInterval.start..<dateInterval.end
            let timeText = dateRange.formatted(
                .components(style: .abbreviated, fields: [.day, .hour, .minute])
            )
            
            // Format the route's distance.
            let distanceText = route.totalLength.formatted()
            
            routeInfoText = "\(timeText) (\(distanceText))"
        }
    }
    
    /// An enumeration representing the different groups of route features in this sample.
    enum RouteFeatures {
        /// The stops along the route.
        case stops
        
        /// The areas that can't be crossed by the route.
        case barriers
    }
}

private extension URL {
    /// The URL to a network analysis server of San Diego, CA, USA on ArcGIS Online.
    static var sanDiegoNetworkAnalysis: URL {
        URL(
            string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/NetworkAnalysis/SanDiego/NAServer/Route"
        )!
    }
}
