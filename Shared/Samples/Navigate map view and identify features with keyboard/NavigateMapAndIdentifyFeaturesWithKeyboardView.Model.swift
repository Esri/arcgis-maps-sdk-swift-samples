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
import UIKit.UIColor

extension NavigateMapAndIdentifyFeaturesWithKeyboardView {
    /// The model for the sample.
    @MainActor
    @Observable
    final class Model {
        /// The number of features that can be identified with number keys at one time.
        private static let featuresPerGroup = 9
        
        /// Buffer distance (meters) around the selection geometry to account for edge cases.
        private static let selectionBufferDistance: Double = 60
        
        /// Attribute used to title and label each feature.
        private static let nameAttribute = "name"
        
        /// Colors used for the marker, selection halo, and label.
        private static let markerFillColor = UIColor(red: 11 / 255, green: 79 / 255, blue: 138 / 255, alpha: 1)
        static let selectionHaloColor = Color(red: 190 / 255, green: 24 / 255, blue: 93 / 255)
        private static let labelTextColor = UIColor(red: 31 / 255, green: 35 / 255, blue: 40 / 255, alpha: 1)
        
        /// The map displayed in the map view.
        let map: Map
        
        /// The feature table of restaurants in Redlands.
        private let restaurantsTable = ServiceFeatureTable(url: .redlandsRestaurants)
        
        /// The feature layer holding the restaurants displayed and identified by the sample.
        private let restaurantsLayer: FeatureLayer
        
        /// The overlay for the numbered 1-9 labels.
        let labelOverlay = GraphicsOverlay()
        
        /// Features currently in the area of interest, indexed by the matching number key.
        private(set) var numberedFeatures: [Feature] = []
        
        /// Features currently in the area of interest, sorted in screen reading order.
        private var queriedFeatures: [OrderedFeature] = []
        
        /// The start index of the currently displayed group of numbered features.
        private var displayedFeaturesIndex = 0
        
        /// A Boolean value indicating whether more than nine features are selected.
        private(set) var hasMoreThanNineSelectedFeatures = false
        
        /// A Boolean value indicating whether there is another group of features to display.
        var canShowNextFeatureGroup: Bool {
            displayedFeaturesIndex + Self.featuresPerGroup < queriedFeatures.endIndex
        }
        
        /// A Boolean value indicating whether there is a previous group of features to display.
        var canShowPreviousFeatureGroup: Bool {
            displayedFeaturesIndex > 0
        }
        
        init() {
            restaurantsLayer = FeatureLayer(featureTable: restaurantsTable)
            restaurantsLayer.renderer = SimpleRenderer(symbol: Self.restaurantSymbol)
            
            let map = Map(basemapStyle: .arcGISLightGray)
            map.initialViewpoint = Viewpoint(
                center: Point(x: -117.1825, y: 34.0556, spatialReference: .wgs84),
                scale: 4_000
            )
            map.addOperationalLayer(restaurantsLayer)
            self.map = map
        }
        
        /// Ensures the feature table is fully loaded before querying.
        func ensureTableLoaded() async throws {
            // Load the feature table to ensure metadata and features are available.
            try await restaurantsTable.load()
        }
        
        func selectFeatures(
            intersecting selectionGeometry: Geometry?,
            containsScreenPoint: (CGPoint) -> Bool,
            screenPointFor: (Point) -> CGPoint?
        ) async throws {
            clearSelection()
            
            guard let selectionGeometry else { return }
            
            let featuresWithScreenPoints = try await makeFeatures(intersecting: selectionGeometry)
                .compactMap { orderedFeature -> (orderedFeature: OrderedFeature, screenPoint: CGPoint)? in
                    guard let screenPoint = screenPointFor(orderedFeature.anchor),
                          containsScreenPoint(screenPoint) else { return nil }
                    return (orderedFeature, screenPoint)
                }
            
            let orderedFeatures = featuresWithScreenPoints
                .sorted { lhs, rhs in
                    if lhs.screenPoint.y != rhs.screenPoint.y { return lhs.screenPoint.y < rhs.screenPoint.y }
                    if lhs.screenPoint.x != rhs.screenPoint.x { return lhs.screenPoint.x < rhs.screenPoint.x }
                    let lhsName = name(for: lhs.orderedFeature.feature, fallback: "") ?? ""
                    let rhsName = name(for: rhs.orderedFeature.feature, fallback: "") ?? ""
                    return lhsName.localizedStandardCompare(rhsName) == .orderedAscending
                }
                .map(\.orderedFeature)
            
            queriedFeatures = orderedFeatures
            displayedFeaturesIndex = 0
            hasMoreThanNineSelectedFeatures = orderedFeatures.count > Self.featuresPerGroup
            
            // Select all intersecting features; only the current group is numbered/labeled.
            restaurantsLayer.selectFeatures(queriedFeatures.map(\.feature))
            updateDisplayedFeatures(announce: true)
        }
        
        /// Displays the next group of queried features, if one exists.
        func nextGroupOfFeatures() {
            guard canShowNextFeatureGroup else { return }
            
            displayedFeaturesIndex += Self.featuresPerGroup
            updateDisplayedFeatures(announce: true)
        }
        
        /// Displays the previous group of queried features, if one exists.
        func previousGroupOfFeatures() {
            guard canShowPreviousFeatureGroup else { return }
            
            displayedFeaturesIndex = max(displayedFeaturesIndex - Self.featuresPerGroup, 0)
            updateDisplayedFeatures(announce: true)
        }
        
        /// Clears selected features, label graphics, and numbered feature state.
        func clearSelection() {
            restaurantsLayer.clearSelection()
            labelOverlay.removeAllGraphics()
            queriedFeatures.removeAll()
            numberedFeatures.removeAll()
            displayedFeaturesIndex = 0
            hasMoreThanNineSelectedFeatures = false
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
        
        /// Queries restaurant features intersecting the given geometry.
        /// - Parameter geometry: The geometry used to query restaurant features.
        /// - Returns: The restaurant features with their map positions.
        private func makeFeatures(intersecting geometry: Geometry) async throws -> [OrderedFeature] {
            // Add a buffer to catch features near the rectangle edges.
            // This accounts for projection distortions and rendering tolerances.
            let queryGeometry = GeometryEngine.buffer(around: geometry, distance: Self.selectionBufferDistance) ?? geometry
            
            let queryParameters = QueryParameters()
            queryParameters.geometry = queryGeometry
            queryParameters.spatialRelationship = .intersects
            queryParameters.maxFeatures = 1000
            
            let queryResult = try await restaurantsTable.queryFeatures(using: queryParameters)
            let allFeatures = Array(queryResult.features())
            
            return allFeatures
                .compactMap { feature -> OrderedFeature? in
                    guard let anchor = feature.geometry as? Point else { return nil }
                    return OrderedFeature(feature: feature, anchor: anchor)
                }
        }
        
        /// Updates labels and number-key targets for the current group of queried features.
        /// - Parameter announce: A Boolean value indicating whether to announce the new group.
        private func updateDisplayedFeatures(announce: Bool) {
            labelOverlay.removeAllGraphics()
            numberedFeatures.removeAll()
            addNumberedLabels(for: featuresForNextStartIndex(displayedFeaturesIndex))
            
            if announce {
                announceDisplayedFeatures()
            }
        }
        
        /// Returns a slice of queried features beginning at the given start index.
        /// - Parameter nextStartIndex: The index of the first feature to display.
        /// - Returns: The next group of features, or the remaining features if fewer than a full group remain.
        private func featuresForNextStartIndex(_ nextStartIndex: Int) -> ArraySlice<OrderedFeature> {
            guard nextStartIndex < queriedFeatures.endIndex else { return [] }
            
            let endIndex = min(nextStartIndex + Self.featuresPerGroup, queriedFeatures.endIndex)
            return queriedFeatures[nextStartIndex..<endIndex]
        }
        
        /// Announces the keyboard commands for the currently displayed features.
        private func announceDisplayedFeatures() {
            let poiMessage = numberedFeatures.enumerated()
                .map { index, feature in
                    let featureTitle = name(for: feature, fallback: "Point of Interest") ?? "Point of Interest"
                    return "Press \(index + 1), \(featureTitle)."
                }
                .joined(separator: " ")
            
            guard !poiMessage.isEmpty else { return }
            
            var lowPriority = AttributedString(poiMessage)
            lowPriority.accessibilitySpeechAnnouncementPriority = .low
            AccessibilityNotification.Announcement(lowPriority).post()
        }
        
        /// Adds numbered text labels for the displayed restaurant features.
        /// - Parameter orderedFeatures: The ordered restaurant features to label.
        private func addNumberedLabels(for orderedFeatures: ArraySlice<OrderedFeature>) {
            let numberedOrderedFeatures = orderedFeatures.prefix(Self.featuresPerGroup)
            
            for (offset, orderedFeature) in numberedOrderedFeatures.enumerated() {
                let number = offset + 1
                let text = name(for: orderedFeature.feature, fallback: nil).map { "\(number): \($0)" } ?? "\(number)"
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
                labelOverlay.addGraphic(Graphic(geometry: orderedFeature.anchor, symbol: labelSymbol))
                numberedFeatures.append(orderedFeature.feature)
            }
        }
        
        /// Returns the keyboard equivalent for a displayed feature index.
        /// - Parameter index: The displayed feature's zero-based index in the current group.
        /// - Returns: The key equivalent used to identify the feature.
        func key(forDisplayedFeatureAtIndex index: Int) -> KeyEquivalent {
            let character: Character = if index < Self.featuresPerGroup {
                Character("\(index + 1)")
            } else {
                "0"
            }
            return KeyEquivalent(character)
        }
        
        /// The restaurant marker symbol.
        private static var restaurantSymbol: SimpleMarkerSymbol {
            let symbol = SimpleMarkerSymbol(style: .circle, color: markerFillColor, size: 12)
            symbol.outline = SimpleLineSymbol(style: .solid, color: .white, width: 1.5)
            return symbol
        }
        
        /// A feature and its map location.
        private struct OrderedFeature {
            let feature: Feature
            let anchor: Point
        }
    }
}

private extension URL {
    /// The URL of the Redlands restaurants feature service.
    static var redlandsRestaurants: URL {
        URL(string: "https://services2.arcgis.com/ZQgQTuoyBrtmoGdP/arcgis/rest/services/redlands_food/FeatureServer/0")!
    }
}
