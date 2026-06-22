// Copyright 2026 Esri
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

extension NavigateMapAndIdentifyFeaturesWithKeyboardView {
    // MARK: - Model
    
    /// The view model for the sample.
    @MainActor
    @Observable
    final class Model {
        /// The maximum number of features that can be identified with number keys.
        private static let maximumNumberedFeatures = 9
        
        /// The attribute used to title and label each feature.
        private static let nameAttribute = "name"
        
        /// The map displayed in the map view.
        let map: Map
        
        /// The feature layer holding the restaurants displayed and identified by the sample.
        private let restaurantsLayer: FeatureLayer
        
        /// The feature table of restaurants in Redlands.
        private let restaurantsTable = ServiceFeatureTable(url: .redlandsRestaurants)
        
        /// The overlay for the numbered 1-9 labels.
        let labelOverlay = GraphicsOverlay()
        
        /// Features currently in the area of interest, indexed by the matching number key.
        private(set) var numberedFeatures: [Feature] = []
        
        /// A Boolean value indicating whether more than nine features are selected.
        private(set) var hasMoreThanNineSelectedFeatures = false
        
        init() {
            // Creates and configures the restaurants layer.
            restaurantsLayer = FeatureLayer(featureTable: restaurantsTable)
            restaurantsLayer.renderer = SimpleRenderer(symbol: Self.makeRestaurantSymbol())
            
            // Creates the map and adds the restaurants layer.
            let map = Map(basemapStyle: .arcGISLightGray)
            map.initialViewpoint = Viewpoint(
                center: Point(x: -117.1825, y: 34.0556, spatialReference: .wgs84),
                scale: 5_000
            )
            map.addOperationalLayer(restaurantsLayer)
            self.map = map
        }
        
        /// Selects, numbers, and labels restaurant features that intersect a given envelope.
        /// - Parameters:
        ///   - envelope: The envelope used to query restaurant features.
        ///   - screenPointFor: A closure that converts a map location to a screen point.
        func selectFeatures(in envelope: Envelope?, screenPointFor: (Point) -> CGPoint?) async throws {
            resetSelection()
            
            guard let envelope else { return }
            
            let orderedFeatures = try await makeOrderedFeatures(
                intersecting: envelope,
                screenPointFor: screenPointFor
            )
            
            hasMoreThanNineSelectedFeatures = orderedFeatures.count > Self.maximumNumberedFeatures
            restaurantsLayer.selectFeatures(orderedFeatures.map(\.feature))
            addNumberedLabels(for: orderedFeatures)
        }
        
        /// Reads the feature's name attribute, returning the fallback when it is missing or blank.
        /// - Parameters:
        ///   - feature: The feature whose name is read.
        ///   - fallback: The value to return when the feature has no name.
        /// - Returns: The feature's name, or the fallback if no name exists.
        func name(for feature: Feature, fallback: String?) -> String? {
            guard let name = feature.attributes[Self.nameAttribute] as? String,
                  !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return fallback
            }
            return name
        }
        
        /// Clears selected features, label graphics, and numbered feature state.
        private func resetSelection() {
            restaurantsLayer.clearSelection()
            labelOverlay.removeAllGraphics()
            numberedFeatures.removeAll()
            hasMoreThanNineSelectedFeatures = false
        }
        
        /// Queries and sorts restaurant features from top-to-bottom, then left-to-right in screen space.
        /// - Parameters:
        ///   - envelope: The envelope used to query restaurant features.
        ///   - screenPointFor: A closure that converts a map location to a screen point.
        /// - Returns: The ordered restaurant features with their map and screen positions.
        private func makeOrderedFeatures(
            intersecting envelope: Envelope,
            screenPointFor: (Point) -> CGPoint?
        ) async throws -> [OrderedFeature] {
            let queryParameters = QueryParameters()
            queryParameters.geometry = envelope
            queryParameters.spatialRelationship = .intersects
            
            let queryResult = try await restaurantsTable.queryFeatures(using: queryParameters)
            return queryResult.features()
                .compactMap { feature -> OrderedFeature? in
                    guard let anchor = feature.geometry as? Point,
                          let screenPoint = screenPointFor(anchor) else {
                        return nil
                    }
                    return OrderedFeature(feature: feature, anchor: anchor, screenPoint: screenPoint)
                }
                .sorted { lhs, rhs in
                    if lhs.screenPoint.y != rhs.screenPoint.y {
                        lhs.screenPoint.y < rhs.screenPoint.y
                    } else {
                        lhs.screenPoint.x < rhs.screenPoint.x
                    }
                }
        }
        
        /// Adds numbered text labels for the first restaurant features.
        /// - Parameter orderedFeatures: The ordered restaurant features to label.
        private func addNumberedLabels(for orderedFeatures: [OrderedFeature]) {
            let numberedOrderedFeatures = orderedFeatures.prefix(Self.maximumNumberedFeatures)
            
            for (offset, orderedFeature) in numberedOrderedFeatures.enumerated() {
                let number = offset + 1
                let text = name(for: orderedFeature.feature, fallback: nil).map { "\(number): \($0)" } ?? "\(number)"
                let labelSymbol = makeTextSymbol(text: text)
                labelOverlay.addGraphic(Graphic(geometry: orderedFeature.anchor, symbol: labelSymbol))
                numberedFeatures.append(orderedFeature.feature)
            }
        }
        
        /// Creates a restaurant marker symbol.
        /// - Returns: A simple marker symbol for restaurants.
        private static func makeRestaurantSymbol() -> SimpleMarkerSymbol {
            let markerFillColor = UIColor(red: 11 / 255, green: 79 / 255, blue: 138 / 255, alpha: 1)
            let symbol = SimpleMarkerSymbol(style: .circle, color: markerFillColor, size: 12)
            symbol.outline = SimpleLineSymbol(style: .solid, color: .white, width: 1.5)
            return symbol
        }
        
        /// Creates a text symbol for a numbered label.
        /// - Parameter text: The text to display in the label.
        /// - Returns: A text symbol for the numbered label.
        private func makeTextSymbol(text: String) -> TextSymbol {
            let labelTextColor = UIColor(red: 31 / 255, green: 35 / 255, blue: 40 / 255, alpha: 1)
            let labelSymbol = TextSymbol(
                text: text,
                color: labelTextColor,
                size: 15,
                horizontalAlignment: .center,
                verticalAlignment: .top
            )
            labelSymbol.haloColor = .white
            labelSymbol.haloWidth = 2
            labelSymbol.offsetY = -14
            return labelSymbol
        }
    }
}

// MARK: - Helper Types

extension NavigateMapAndIdentifyFeaturesWithKeyboardView.Model {
    /// The color used for the selection halo.
    static let selectionHaloColor = Color(red: 190 / 255, green: 24 / 255, blue: 93 / 255)
    
    /// A feature and its screen-space ordering information.
    struct OrderedFeature {
        /// The feature from the feature table.
        let feature: Feature
        /// The map location of the feature.
        let anchor: Point
        /// The screen location of the feature.
        let screenPoint: CGPoint
    }
}

private extension URL {
    /// The URL of the Redlands restaurants feature service.
    static var redlandsRestaurants: URL {
        URL(string: "https://services2.arcgis.com/ZQgQTuoyBrtmoGdP/arcgis/rest/services/redlands_food/FeatureServer/0")!
    }
}
