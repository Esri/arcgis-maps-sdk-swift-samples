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
import UIKit.UIColor

extension NavigateMapAndIdentifyFeaturesWithKeyboardView {
    /// The model for the sample.
    @MainActor
    @Observable
    final class Model {
        /// The maximum number of features that can be identified with number keys.
        private static let maximumNumberedFeatures = 9
        
        /// The buffer distance, in meters, around the selection envelope to catch
        /// features near the rectangle edges.
        private static let selectionBufferDistance = 70.0
        
        /// The color of the halo around selected features.
        static let selectionHaloColor = Color(red: 190 / 255, green: 24 / 255, blue: 93 / 255)
        
        /// The map displayed in the map view.
        let map: Map
        
        /// The feature table of restaurants in Redlands.
        private let restaurantsTable = ServiceFeatureTable(url: .redlandsRestaurants)
        
        /// The feature layer of restaurants displayed and identified by the sample.
        private let restaurantsLayer: FeatureLayer
        
        /// The overlay for the numbered 1-9 labels.
        let labelOverlay = GraphicsOverlay()
        
        /// The features currently in the area of interest, indexed by the matching number key.
        private(set) var numberedFeatures: [Feature] = []
        
        /// A Boolean value indicating whether more than nine features are selected.
        private(set) var hasMoreThanNineSelectedFeatures = false
        
        init() {
            let markerSymbol = SimpleMarkerSymbol(
                style: .circle,
                color: UIColor(red: 11 / 255, green: 79 / 255, blue: 138 / 255, alpha: 1),
                size: 12
            )
            markerSymbol.outline = SimpleLineSymbol(style: .solid, color: .white, width: 1.5)
            
            restaurantsLayer = FeatureLayer(featureTable: restaurantsTable)
            restaurantsLayer.renderer = SimpleRenderer(symbol: markerSymbol)
            
            map = Map(basemapStyle: .arcGISLightGray)
            map.initialViewpoint = Viewpoint(
                center: Point(x: -117.1825, y: 34.0556, spatialReference: .wgs84),
                scale: 4_000
            )
            map.addOperationalLayer(restaurantsLayer)
        }
        
        /// Loads the feature table so it is ready for querying.
        func ensureLayerLoaded() async throws {
            try await restaurantsTable.load()
        }
        
        /// Selects, numbers, and labels the restaurant features that intersect a given envelope.
        /// - Parameter envelope: The envelope used to query restaurant features.
        func selectFeatures(in envelope: Envelope?) async throws {
            clearSelection()
            guard let envelope else { return }
            
            let orderedFeatures = try await queryOrderedFeatures(intersecting: envelope)
            hasMoreThanNineSelectedFeatures = orderedFeatures.count > Self.maximumNumberedFeatures
            
            for (offset, orderedFeature) in orderedFeatures.prefix(Self.maximumNumberedFeatures).enumerated() {
                let number = offset + 1
                let text = name(for: orderedFeature.feature).map { "\(number): \($0)" } ?? "\(number)"
                labelOverlay.addGraphic(
                    Graphic(geometry: orderedFeature.anchor, symbol: Self.makeLabelSymbol(text: text))
                )
                numberedFeatures.append(orderedFeature.feature)
            }
            
            restaurantsLayer.selectFeatures(numberedFeatures)
        }
        
        /// Clears selected features, label graphics, and numbered feature state.
        func clearSelection() {
            restaurantsLayer.clearSelection()
            labelOverlay.removeAllGraphics()
            numberedFeatures.removeAll()
            hasMoreThanNineSelectedFeatures = false
        }
        
        /// The feature's non-empty name attribute, if it has one.
        /// - Parameter feature: The feature whose name is read.
        /// - Returns: The feature's name, or `nil` if the attribute is missing or blank.
        func name(for feature: Feature) -> String? {
            guard let name = feature.attributes["name"] as? String,
                  !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            return name
        }
        
        /// Queries restaurant features intersecting an envelope, sorted north-to-south,
        /// then west-to-east.
        /// - Parameter envelope: The envelope used to query restaurant features.
        /// - Returns: The ordered restaurant features with their map positions.
        private func queryOrderedFeatures(
            intersecting envelope: Envelope
        ) async throws -> [(feature: Feature, anchor: Point)] {
            // Buffer the envelope to catch features near the rectangle edges.
            let bufferedEnvelope = GeometryEngine.buffer(
                around: envelope,
                distance: Self.selectionBufferDistance
            )?.extent ?? envelope
            
            let queryParameters = QueryParameters()
            queryParameters.geometry = bufferedEnvelope
            queryParameters.spatialRelationship = .intersects
            
            let queryResult = try await restaurantsTable.queryFeatures(using: queryParameters)
            return queryResult.features()
                .compactMap { feature -> (feature: Feature, anchor: Point)? in
                    guard let anchor = feature.geometry as? Point else { return nil }
                    return (feature, anchor)
                }
                .sorted { lhs, rhs in
                    lhs.anchor.y != rhs.anchor.y
                        ? lhs.anchor.y > rhs.anchor.y
                        : lhs.anchor.x < rhs.anchor.x
                }
        }
        
        /// Makes the text symbol for a numbered feature label.
        /// - Parameter text: The label's text.
        private static func makeLabelSymbol(text: String) -> TextSymbol {
            let symbol = TextSymbol(
                text: text,
                color: UIColor(red: 31 / 255, green: 35 / 255, blue: 40 / 255, alpha: 1),
                size: 15,
                horizontalAlignment: .center,
                verticalAlignment: .top
            )
            symbol.haloColor = .white
            symbol.haloWidth = 2
            symbol.offsetY = -14
            return symbol
        }
    }
}

private extension URL {
    /// The URL of the Redlands restaurants feature service.
    static var redlandsRestaurants: URL {
        URL(string: "https://services2.arcgis.com/ZQgQTuoyBrtmoGdP/arcgis/rest/services/redlands_food/FeatureServer/0")!
    }
}
