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

extension GeocodeOfflineView {
    /// The view model for the sample.
    @MainActor
    class Model: ObservableObject {
        // MARK: Properties
        
        /// A map with a tiled layer of the streets in San Diego, CA, USA.
        let map = {
            // Create a tiled layer using the local tile package.
            let tileCache = TileCache(fileURL: .streetMap)
            let tiledLayer = ArcGISTiledLayer(tileCache: tileCache)
            
            // Create a map with the tiled layer as base layer.
            return Map(basemap: Basemap(baseLayer: tiledLayer))
        }()
        
        /// The graphics overlay for the marker graphic.
        let graphicsOverlay = GraphicsOverlay()
        
        /// The red map marker graphic used to indicate a given location on the map.
        private let markerGraphic = {
            // Create a symbol using the image from the project assets.
            guard let markerImage = UIImage(named: "RedMarker") else { return Graphic() }
            let markerSymbol = PictureMarkerSymbol(image: markerImage)
            
            // Change the symbol's offsets, so it aligns properly to a given point.
            markerSymbol.leaderOffsetY = markerImage.size.height / 2
            markerSymbol.offsetY = markerImage.size.height / 2
            
            // Create a graphic with the symbol.
            return Graphic(symbol: markerSymbol)
        }()
        
        /// The locator task used to preform the geocode operations, loaded from a local file.
        private let locatorTask = LocatorTask(name: "SanDiego_StreetAddress", bundle: .main)
        
        /// The viewpoint of the map view, initially centered on San Diego, CA, USA.
        @Published var viewpoint = Viewpoint(
            center: Point(x: -13_042_250, y: 3_857_970, spatialReference: .webMercator),
            scale: 2e4
        )
        
        /// The placement of the callout on the map.
        @Published var calloutPlacement: CalloutPlacement?
        
        /// A Boolean value indicating whether the callout placement should be offsetted, e.g. when the map magnifier is showing.
        @Published var calloutShouldOffset = false
        
        /// The text shown in the callout.
        @Published private(set) var calloutText: String = ""
        
        /// A Boolean value indicating whether to show an error alert.
        @Published var isShowingErrorAlert = false
        
        /// The error shown in the error alert.
        @Published private(set) var error: Error? {
            didSet { isShowingErrorAlert = error != nil }
        }
        
        init() {
            graphicsOverlay.addGraphic(markerGraphic)
        }
        
        // MARK: Methods
        
        /// Geocodes a given address and adds a marker with the corresponding address at the result's location.
        /// - Parameter address: The given text address to geocode.
        func geocodeSearch(address: String) async {
            guard let locatorTask else { return }
            
            // Create geocode parameters.
            let geocodeParameters = GeocodeParameters()
            geocodeParameters.addResultAttributeName("Match_addr")
            geocodeParameters.minScore = 75
            
            do {
                // Perform geocode using the locator task with the text address and parameters.
                let geocodeResults = try await locatorTask.geocode(
                    forSearchText: address,
                    using: geocodeParameters
                )
                
                if let result = geocodeResults.first,
                   let displayLocation = result.displayLocation {
                    // If a result is found, place a marker at the result's location.
                    let resultText = result.attributes["Match_addr"] as? String ?? ""
                    updateMarker(to: displayLocation, withText: resultText)
                    
                    // Zoom to the extent of the result's location.
                    viewpoint = Viewpoint(boundingGeometry: displayLocation.extent)
                } else {
                    // If no result was found, inform the user with an alert.
                    throw "No results found"
                }
            } catch {
                self.error = error
            }
        }
        
        /// Reverse geocodes a given location and adds a marker with the corresponding address at the result's location.
        /// - Parameter mapPoint: The point on the map to reverse geocode.
        func reverseGeocode(mapPoint: Point) async {
            guard let locatorTask else { return }
            
            //  Normalized the map point.
            guard let normalizedPoint = GeometryEngine.normalizeCentralMeridian(
                of: mapPoint
            ) as? Point else { return }
            
            // Create reverse geocode parameters.
            let reverseGeocodeParameters = ReverseGeocodeParameters()
            reverseGeocodeParameters.addResultAttributeName("*")
            reverseGeocodeParameters.maxResults = 1
            
            // Perform reverse geocode using the locator task with the point and parameters.
            let geocodeResults = try? await locatorTask.reverseGeocode(
                forLocation: normalizedPoint,
                parameters: reverseGeocodeParameters
            )
            
            let resultText: String
            if let result = geocodeResults?.first {
                // If a result is found, extract the address from the attributes.
                let cityString = result.attributes["City"] as? String ?? ""
                let streetString = result.attributes["StAddr"] as? String ?? ""
                let stateString = result.attributes["Region"] as? String ?? ""
                
                resultText = "\(streetString), \(cityString), \(stateString)"
            } else {
                resultText = "No address found"
            }
            
            // Create a marker at the location with the text.
            updateMarker(to: normalizedPoint, withText: resultText)
        }
        
        /// Resets the callout and marker graphic, removing them from the map view.
        func resetGraphics() {
            calloutPlacement = nil
            markerGraphic.geometry = nil
        }
        
        /// Updates the callout placement to a given location.
        /// - Parameter mapPoint: The point on the map to update the callout placement to.
        func updateCalloutPlacement(to mapPoint: Point) {
            if calloutShouldOffset {
                // Offset the callout to the top of the magnifier when it is showing.
                let magnifierOffset = CGPoint(x: .zero, y: -140)
                calloutPlacement = .location(mapPoint, offset: magnifierOffset)
            } else {
                calloutPlacement = .geoElement(markerGraphic, tapLocation: mapPoint)
            }
        }
        
        /// Updates the map marker and its associated callout to a given location.
        /// - Parameters:
        ///   - mapPoint: The point on the map to move the marker graphic to.
        ///   - text: The text to show in the marker's callout.
        private func updateMarker(to mapPoint: Point, withText text: String) {
            markerGraphic.geometry = mapPoint
            calloutText = text
            updateCalloutPlacement(to: mapPoint)
        }
    }
}

extension String: LocalizedError {
    /// The description of the error.
    public var errorDescription: String? { self }
}

private extension URL {
    /// A URL to the local tile package of the streets in San Diego, CA, USA.
    static var streetMap: Self {
        Bundle.main.url(forResource: "streetmap_SD", withExtension: "tpkx")!
    }
}
