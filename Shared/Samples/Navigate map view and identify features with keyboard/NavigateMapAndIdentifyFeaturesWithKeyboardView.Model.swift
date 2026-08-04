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
import Foundation
import SwiftUI
import UIKit

extension NavigateMapAndIdentifyFeaturesWithKeyboardView {
    /// The model for the sample.
    @MainActor
    @Observable
    final class Model {
        /// The maximum number of features that can be identified with number keys.
        private static let maximumNumberedFeatures = 9
        
        /// Attribute used to title and label each feature.
        private static let nameAttribute = "name"
        
        /// Colors used for the marker, selection halo, and label.
        private static let markerFillColor = UIColor(
            red: 11 / 255,
            green: 79 / 255,
            blue: 138 / 255,
            alpha: 1
        )
        
        static let selectionHaloColor = Color(
            red: 190 / 255,
            green: 24 / 255,
            blue: 93 / 255
        )
        
        private static let labelTextColor = UIColor(
            red: 31 / 255,
            green: 35 / 255,
            blue: 40 / 255,
            alpha: 1
        )
        
        /// The feature table of restaurants in Redlands.
        private let restaurantsTable = ServiceFeatureTable(url: .redlandsRestaurants)
        
        /// The feature layer holding the restaurants displayed and identified by the sample.
        let restaurantsLayer: FeatureLayer
        
        /// The overlay for the numbered 1-9 labels.
        let labelOverlay = GraphicsOverlay()
        
        /// Features currently in the area of interest, indexed by the matching number key.
        private(set) var numberedFeatures: [Feature] = []
        
        /// A Boolean value indicating whether more than nine features are selected.
        private(set) var hasMoreThanNineSelectedFeatures = false
        
        init() {
            let restaurantSymbol = SimpleMarkerSymbol(
                style: .circle,
                color: Self.markerFillColor,
                size: 12
            )
            restaurantSymbol.outline = SimpleLineSymbol(
                style: .solid,
                color: .white,
                width: 1.5
            )
            
            restaurantsLayer = FeatureLayer(featureTable: restaurantsTable)
            restaurantsLayer.renderer = SimpleRenderer(symbol: restaurantSymbol)
        }
        
        /// Selects, numbers, and labels restaurant features that intersect a given polygon.
        /// - Parameters:
        ///   - polygon: The polygon used to query restaurant features.
        ///   - pointConverter: A closure that converts a map location to a screen point.
        func selectFeatures(in polygon: Polygon, pointConverter: (Point) -> CGPoint?) async throws {
            if restaurantsTable.loadStatus != .loaded {
                try await restaurantsTable.load()
            }
            
            clearSelection()
            
            let orderedFeatures = try await makeOrderedFeatures(
                polygon,
                pointConverter: pointConverter
            )
            
            hasMoreThanNineSelectedFeatures = orderedFeatures.count > Self.maximumNumberedFeatures
            
            // Only select the numbered features (first 9).
            let numberedOrderedFeatures = orderedFeatures.lazy
                .map(\.feature)
                .prefix(Self.maximumNumberedFeatures)
            restaurantsLayer.selectFeatures(numberedOrderedFeatures)
            
            addNumberedLabels(for: orderedFeatures)
        }
        
        /// Clears selected features, label graphics, and numbered feature state.
        func clearSelection() {
            restaurantsLayer.clearSelection()
            labelOverlay.removeAllGraphics()
            numberedFeatures.removeAll()
            hasMoreThanNineSelectedFeatures = false
        }
        
        /// Reads the feature's name attribute.
        /// - Parameter feature: The feature whose name is read.
        /// - Returns: The feature's name, or `nil` if no name exists.
        func name(for feature: Feature) -> String? {
            guard let name = feature.attributes[Self.nameAttribute] as? String else {
                return nil
            }
            
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard !trimmedName.isEmpty else {
                return nil
            }
            
            return trimmedName
        }
        
        /// Queries and sorts restaurant features from top-to-bottom, then left-to-right in screen space.
        /// - Parameters:
        ///   - selection: The polygon used to query restaurant features.
        ///   - pointConverter: A closure that converts a map location to a screen point.
        /// - Returns: The ordered restaurant features with their map and screen positions.
        private func makeOrderedFeatures(
            _ selection: Polygon,
            pointConverter: (Point) -> CGPoint?
        ) async throws -> [OrderedFeature] {
            let queryParameters = QueryParameters()
            queryParameters.geometry = selection
            queryParameters.spatialRelationship = .intersects
            queryParameters.maxFeatures = 1000
            
            let queryResult = try await restaurantsTable.queryFeatures(using: queryParameters)
            
            return withoutActuallyEscaping(pointConverter) { escapablePointConverter in
                queryResult
                    .features()
                    .lazy
                    .compactMap { feature in
                        guard let anchor = feature.geometry as? Point,
                              let screenPoint = escapablePointConverter(anchor) else {
                            return nil
                        }
                        return OrderedFeature(feature: feature, anchor: anchor, screenPoint: screenPoint)
                    }
                    .sorted { lhs, rhs in
                        // Sort by visual reading order: top-to-bottom, then
                        // left-to-right.
                        return if lhs.screenPoint.y != rhs.screenPoint.y {
                            lhs.screenPoint.y < rhs.screenPoint.y
                        } else {
                            lhs.screenPoint.x < rhs.screenPoint.x
                        }
                    }
            }
        }
        
        /// Adds numbered text labels for the first restaurant features.
        /// - Parameter orderedFeatures: The ordered restaurant features to label.
        private func addNumberedLabels(for orderedFeatures: [OrderedFeature]) {
            let numberedOrderedFeatures = orderedFeatures.prefix(Self.maximumNumberedFeatures)
            
            for (offset, orderedFeature) in numberedOrderedFeatures.enumerated() {
                let number = offset + 1
                let text = name(for: orderedFeature.feature).map { "\(number): \($0)" } ?? "\(number)"
                let labelSymbol = TextSymbol(
                    text: text,
                    color: Self.labelTextColor,
                    size: 15,
                    horizontalAlignment: .center,
                    verticalAlignment: .top
                )
                labelSymbol.haloColor = .white
                labelSymbol.haloWidth = 2
                labelSymbol.offsetY = -14
                labelOverlay.addGraphic(
                    Graphic(geometry: orderedFeature.anchor, symbol: labelSymbol)
                )
                numberedFeatures.append(orderedFeature.feature)
            }
        }
        
        /// A feature and its map and screen locations.
        private struct OrderedFeature {
            let feature: Feature
            let anchor: Point
            let screenPoint: CGPoint
        }
    }
}

private extension URL {
    /// The URL of the Redlands restaurants feature service.
    static var redlandsRestaurants: URL {
        URL(string: "https://services2.arcgis.com/ZQgQTuoyBrtmoGdP/arcgis/rest/services/redlands_food/FeatureServer/0")!
    }
}
