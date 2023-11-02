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

extension FindRouteInTransportNetworkView {
    /// The view model for the sample.
    @MainActor
    class Model: ObservableObject {
        // MARK: Properties
        
        /// A map with a tiled basemap of the streets in San Diego, CA, USA.
        let map = {
            // Create a basemap using the local tile package.
            let tileCache = TileCache(fileURL: .sanDiegoStreetMap)
            let tiledLayer = ArcGISTiledLayer(tileCache: tileCache)
            let tiledBasemap = Basemap(baseLayer: tiledLayer)
            
            // Create a map with the basemap and center it on San Deigo.
            let map = Map(basemap: tiledBasemap)
            map.initialViewpoint = Viewpoint(
                center: Point(x: -13_042_250, y: 3_857_970, spatialReference: .webMercator),
                scale: 2e4
            )
            return map
        }()
        
        /// The graphics overlay for the route graphics.
        let routeGraphicsOverlay = GraphicsOverlay()
        
        /// The graphics overlay for the stop graphics.
        let stopGraphicsOverlay = GraphicsOverlay()
        
        /// The route parameters used for routing.
        var routeParameters: RouteParameters?
        
        /// The route task loaded from a local geodatabase file.
        let routeTask = RouteTask(pathToDatabaseURL: .sanDiegoGeodatabase, networkName: "Streets_ND")
        
        /// The symbol for the route graphics.
        private let routeSymbol = SimpleLineSymbol(style: .solid, color: .yellow, width: 5)
        
        /// The blue marker symbol for the stop graphics.
        private let markerSymbol = {
            let markerImage = UIImage(named: "BlueMarker")!
            let markerSymbol = PictureMarkerSymbol(image: markerImage)
            markerSymbol.offsetY = markerImage.size.height / 2
            return markerSymbol
        }()
        
        /// The current count of stop graphics in the stop graphic overlay.
        private var stopGraphicsCount: Int {
            stopGraphicsOverlay.graphics.count
        }
        
        /// The route info containing the time and distance of the combined routes on the screen.
        @Published private(set) var routeInfo = RouteInfo()
        
        // MARK: Methods
        
        /// Adds a stop to the route along with a stop graphic.
        /// - Parameters:
        ///   - mapPoint: The point on the map to add the route stop and stop graphic at.
        ///   - replacingLast: A Boolean value indicating whether to replace the last stop with the new one.
        func addRouteStop(at mapPoint: Point, replacingLast: Bool = false) {
            if replacingLast {
                // Update the last stop graphic's geometry, e.g. magnifier is showing.
                stopGraphicsOverlay.graphics.last?.geometry = mapPoint
            } else {
                // Create a new stop graphic.
                addStopGraphic(at: mapPoint)
            }
            
            // Add a route graphic for the stop.
            updateRouteParametersStops(using: stopGraphicsCount - 2..<stopGraphicsCount)
            addRoute(replacingLast: replacingLast)
        }
        
        /// Creates a route using the route parameters and adds a graphic for the route to the map.
        /// - Parameter replacingLast: A Boolean value indicating whether to replace the last route with the new one.
        func addRoute(replacingLast: Bool = false) {
            Task { [weak self] in
                guard let self, let routeParameters else { return }
                
                // Get the route from the route task using the route parameters.
                let routeResult = try? await routeTask.solveRoute(using: routeParameters)
                guard let route = routeResult?.routes.first else { return }
                
                let routeGraphic: Graphic
                if replacingLast {
                    // Get the last graphic from the route graphics overlay.
                    guard let lastRouteGraphic = routeGraphicsOverlay.graphics.last else { return }
                    routeGraphic = lastRouteGraphic
                    
                    // Remove the last route's time and distance from the total.
                    if let lastRouteTime = routeGraphic.attributes["routeTime"] as? TimeInterval {
                        routeInfo.totalTime -= lastRouteTime
                    }
                    if let lastRouteDistance = routeGraphic.attributes["routeLength"] as? Measurement<UnitLength> {
                        routeInfo.totalDistance -= lastRouteDistance
                    }
                } else {
                    // Create a graphic for the route and add to the route graphics overlay.
                    routeGraphic = Graphic(symbol: routeSymbol)
                    routeGraphicsOverlay.addGraphic(routeGraphic)
                }
                
                // Update the graphic's geometry and attributes.
                routeGraphic.geometry = route.geometry
                routeGraphic.setAttributeValue(route.totalTime, forKey: "routeTime")
                routeGraphic.setAttributeValue(route.totalLength, forKey: "routeLength")
                
                // Update the total time and distance.
                routeInfo.totalTime += route.totalTime
                routeInfo.totalDistance += route.totalLength
            }
        }
        
        /// Sets the route parameters' travel mode and updates the current route accordingly.
        /// - Parameter mode: The new travel mode used to update the route parameters.
        func updateTravelMode(to mode: TravelModeOption) {
            // Update the route parameter's travel mode.
            routeParameters?.travelMode = routeTask.info.travelModes[mode.rawValue]
            
            // Update the route parameters stops to include all of the current stops.
            updateRouteParametersStops(using: 0..<stopGraphicsCount)
            
            // Reset the previous routes.
            routeGraphicsOverlay.removeAllGraphics()
            routeInfo.reset()
            
            // Create a new route with the updated route parameters.
            addRoute()
        }
        
        /// Removes the current stops and routes from the screen.
        func reset() {
            // Reset the stops.
            stopGraphicsOverlay.removeAllGraphics()
            routeParameters?.clearStops()
            
            // Reset the routes.
            routeGraphicsOverlay.removeAllGraphics()
            routeInfo.reset()
        }
        
        /// Adds a stop graphic to the map.
        /// - Parameter point: The point on the map to add the stop graphic at.
        private func addStopGraphic(at point: Point) {
            // Create a text symbol with next index.
            let textSymbol = TextSymbol(
                text: "\(stopGraphicsCount + 1)",
                color: .white,
                size: 20,
                horizontalAlignment: .center,
                verticalAlignment: .middle
            )
            textSymbol.offsetY = markerSymbol.offsetY
            
            // Create a graphic with the marker symbol and text symbol.
            let compositeSymbol = CompositeSymbol(symbols: [markerSymbol, textSymbol])
            let stopGraphic = Graphic(geometry: point, symbol: compositeSymbol)
            
            // Add the new graphic to the graphics overlay.
            stopGraphicsOverlay.addGraphic(stopGraphic)
        }
        
        /// Updates the route parameters stops using graphics in the stop graphics overlay.
        /// - Parameter indices: A range of indices corresponding to the graphics to create the stops from.
        private func updateRouteParametersStops(using indices: Range<Int>) {
            guard indices.lowerBound >= 0 && indices.upperBound <= stopGraphicsCount else { return }
            
            // Create a stop for each index in the passed range.
            var stops: [Stop] = []
            for i in indices {
                if let graphicPoint = stopGraphicsOverlay.graphics[i].geometry as? Point {
                    let stop = Stop(point: graphicPoint)
                    stops.append(stop)
                }
            }
            
            // Clear the previous stops from the route parameters.
            routeParameters?.clearStops()
            
            // Set the new stops.
            routeParameters?.setStops(stops)
        }
    }
    
    struct RouteInfo {
        /// The total time in seconds of the combined routes.
        var totalTime: TimeInterval = 0
        
        /// The total distance in meters of the combined routes.
        var totalDistance = Measurement(value: 0, unit: UnitLength.meters)
        
        /// The human-readable label of the route info containing the formatted time and distance.
        var label: String? {
            guard totalTime != 0 && totalDistance.value != 0  else { return nil }
            
            // Format the time.
            let dateInterval = DateInterval(start: .now, duration: totalTime)
            let dateRange = dateInterval.start..<dateInterval.end
            let timeText = dateRange.formatted(
                .components(style: .abbreviated, fields: [.day, .hour, .minute])
            )
            
            // Format the distance.
            let distanceText = totalDistance.formatted()
            
            return "\(timeText) (\(distanceText))"
        }
        
        /// Resets the time and distance to zero.
        mutating func reset() {
            totalTime = 0
            totalDistance.value = 0
        }
    }
    
    /// An enumeration representing the different travel mode options for this sample.
    enum TravelModeOption: Int {
        case fastest, shortest
    }
}

private extension Measurement {
    /// The subtraction assignment operator for measurements.
    /// - Parameters:
    ///   - lhs: The left hand side measurement to be subtracted from.
    ///   - rhs: The right hand side measurement.
    static func -= (lhs: inout Measurement, rhs: Measurement) {
        lhs = lhs - rhs
    }
    
    /// The addition assignment to operator for measurements.
    /// - Parameters:
    ///   - lhs: The left hand side measurement to be added to.
    ///   - rhs: The right hand side measurement.
    static func += (lhs: inout Measurement, rhs: Measurement) {
        lhs = lhs + rhs
    }
}

private extension URL {
    /// A URL to the local tile package of the streets in San Diego, CA, USA.
    static var sanDiegoStreetMap: Self {
        Bundle.main.url(
            forResource: "streetmap_SD",
            withExtension: "tpkx",
            subdirectory: "san_diego_offline_routing"
        )!
    }
    
    /// A URL to the local geodatabase file of San Diego, CA, USA.
    static var sanDiegoGeodatabase: Self {
        Bundle.main.url(
            forResource: "sandiego",
            withExtension: "geodatabase",
            subdirectory: "san_diego_offline_routing"
        )!
    }
}
