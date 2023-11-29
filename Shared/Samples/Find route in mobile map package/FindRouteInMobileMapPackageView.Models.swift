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

extension FindRouteInMobileMapPackageView {
    /// The view model for the `FindRouteInMobileMapPackageView`.
    @MainActor
    class Model: ObservableObject {
        /// The list of loaded mobile map packages.
        @Published private(set) var mapPackages = [MobileMapPackage]()
        
        /// The error shown in the error alert.
        @Published var error: Error?
        
        /// The list of file URLs that have been securely accessed.
        private var accessedURLs = [URL]()
        
        deinit {
            // Release access to all the accessed URLs.
            for url in accessedURLs {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        /// Imports a mobile map package from a given file URL.
        /// - Parameter URLs: The file URL to the "mmpk" file to import.
        func importMapPackage(from fileURL: URL) async {
            // Make the URL accessible.
            if !accessedURLs.contains(fileURL) && fileURL.startAccessingSecurityScopedResource() {
                accessedURLs.append(fileURL)
            }
            
            // Load the map package.
            await addMapPackage(from: fileURL)
        }
        
        /// Adds a mobile map package to the map packages list using a given file URL.
        /// - Parameter URLs: The file URL to the "mmpk" file to add.
        func addMapPackage(from fileURL: URL) async {
            do {
                let mapPackage = MobileMapPackage(fileURL: fileURL)
                try await mapPackage.load()
                mapPackages.append(mapPackage)
            } catch {
                self.error = error
            }
        }
    }
}

extension FindRouteInMobileMapPackageView.MobileMapView {
    /// The view model for the `FindRouteInMobileMapPackageView.MobileMapView`.
    @MainActor
    class Model: ObservableObject {
        // MARK: Properties
        
        /// The map for the view.
        let map: Map
        
        /// The graphics overlays for the view.
        var graphicsOverlays: [GraphicsOverlay] {
            if let routeGraphicsOverlay {
                return [markerGraphicsOverlay, routeGraphicsOverlay]
            } else {
                return [markerGraphicsOverlay]
            }
        }
        
        /// The graphics overlay for the marker graphics.
        let markerGraphicsOverlay = GraphicsOverlay()
        
        /// The graphics overlay for the route graphics.
        let routeGraphicsOverlay: GraphicsOverlay?
        
        /// The blue marker symbol for creating a marker graphic.
        private let markerSymbol = {
            // Create a symbol using the Blue Marker image from the project's assets.
            let markerImage = UIImage(named: "BlueMarker")!
            let markerSymbol = PictureMarkerSymbol(image: markerImage)
            
            // Change the symbol's offsets, so it aligns properly to a given point.
            markerSymbol.leaderOffsetY = markerImage.size.height / 2
            markerSymbol.offsetY = markerImage.size.height / 2
            
            return markerSymbol
        }()
        
        /// The blue line symbol for creating a route graphic.
        private let routeSymbol = SimpleLineSymbol(style: .solid, color: .blue, width: 5)
        
        /// The route task for routing.
        let routeTask: RouteTask?
        
        /// The route parameters for routing with the route task.
        private var routeParameters: RouteParameters?
        
        /// The locator task for reverse geocoding.
        private let locatorTask: LocatorTask
        
        /// The parameters for reverse geocoding with the locator task.
        private let reverseGeocodeParameters = {
            let reverseGeocodeParameters = ReverseGeocodeParameters()
            reverseGeocodeParameters.addResultAttributeName("*")
            reverseGeocodeParameters.maxResults = 1
            return reverseGeocodeParameters
        }()
        
        /// The count of marker graphics in the marker graphics overlay.
        private var markersCount: Int {
            markerGraphicsOverlay.graphics.count
        }
        
        /// The last marker in the marker graphics overlay.
        var lastMarker: Graphic? {
            markerGraphicsOverlay.graphics.last
        }
        
        init(map: Map, locatorTask: LocatorTask) {
            self.map = map
            self.locatorTask = locatorTask
            
            // Set up the properties used for routing if the map has a transportation network.
            if let transportationNetwork = map.transportationNetworks.first {
                routeGraphicsOverlay = GraphicsOverlay()
                routeTask = RouteTask(dataset: transportationNetwork)
            } else {
                routeGraphicsOverlay = nil
                routeTask = nil
            }
        }
        
        // MARK: Methods
        
        /// Loads the route parameters from the route task.
        func loadRouteParameters() async throws {
            routeParameters = try await routeTask?.makeDefaultParameters()
        }
        
        /// Updates the marker to a given point or adds a new marker if there isn't one yet.
        /// - Parameter point: The point to set the marker to.
        func updateMarker(to point: Point) {
            if lastMarker != nil {
                lastMarker?.geometry = point
            } else {
                let markerGraphic = Graphic(geometry: point, symbol: markerSymbol)
                markerGraphicsOverlay.addGraphic(markerGraphic)
            }
        }
        
        /// Adds a stop to the route.
        /// - Parameters:
        ///   - point: The point to add the stop graphic at.
        func addRouteStop(at point: Point) async throws {
            // Update the last stop instead of adding a new one if there
            // isn't a route for the last one.
            if routeGraphicsOverlay?.graphics.count ?? 0 < markersCount - 1 {
                lastMarker?.geometry = point
            } else {
                addStopGraphic(at: point)
            }
            
            // Create a route using the stop.
            try await addRoute()
        }
        
        /// Reverse geocodes a given point.
        /// - Parameter point: The point to reverse geocode.
        /// - Returns: The resulting address of the reverse geocode if any.
        func reverseGeocode(point: Point) async throws -> String {
            // Perform reverse geocode using the locator task with the point and parameters.
            let geocodeResults = try await locatorTask.reverseGeocode(
                forLocation: point,
                parameters: reverseGeocodeParameters
            )
            
            // If a result is found, extract the address from the attributes.
            if let result = geocodeResults.first {
                // If a result is found, extract the address from the attributes.
                let cityString = result.attributes["City"] as? String ?? ""
                let streetString = result.attributes["StAddr"] as? String ?? ""
                let stateString = result.attributes["Region"] as? String ?? ""
                return "\(streetString), \(cityString), \(stateString)"
            } else {
                return "No address found"
            }
        }
        
        /// Adds a stop graphic to the marker graphics overlay.
        /// - Parameter point: The point to add the stop graphic at.
        private func addStopGraphic(at point: Point) {
            // Create a text symbol with the next marker index.
            let textSymbol = TextSymbol(
                text: "\(markersCount + 1)",
                color: .white,
                size: 20,
                horizontalAlignment: .center,
                verticalAlignment: .middle
            )
            textSymbol.offsetY = markerSymbol.offsetY
            
            // Create a graphic with the marker symbol and text symbol.
            let compositeSymbol = CompositeSymbol(symbols: [markerSymbol, textSymbol])
            let stopGraphic = Graphic(geometry: point, symbol: compositeSymbol)
            
            // Add the new graphic to the marker graphics overlay.
            markerGraphicsOverlay.addGraphic(stopGraphic)
        }
        
        /// Creates a route using the last two marker graphics.
        private func addRoute() async throws {
            guard let routeParameters, markersCount >= 2 else { return }
            
            // Create stops from the last two marker graphics.
            let lastGraphics = markerGraphicsOverlay.graphics[markersCount - 2..<markersCount]
            let stops = lastGraphics.compactMap { graphic -> Stop? in
                guard let point = graphic.geometry as? Point else { return nil }
                return Stop(point: point)
            }
            
            // Set the new stops on the route parameters.
            routeParameters.clearStops()
            routeParameters.setStops(stops)
            
            // Get the route from the route task using the route parameters.
            let routeResult = try await routeTask?.solveRoute(using: routeParameters)
            guard let route = routeResult?.routes.first else { return }
            
            // Create a graphic for the route and add to the route graphics overlay.
            let routeGraphic = Graphic(geometry: route.geometry, symbol: routeSymbol)
            routeGraphicsOverlay?.addGraphic(routeGraphic)
        }
    }
}
