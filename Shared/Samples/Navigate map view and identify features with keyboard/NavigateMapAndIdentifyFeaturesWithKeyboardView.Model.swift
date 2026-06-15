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
    /// The model for the sample.
    @MainActor
    @Observable
    final class Model {
        /// Attribute used to title and label each feature.
        private static let nameAttribute = "name"
        
        /// Colors used for the marker, selection halo, and label.
        private static let markerFillColor = UIColor(red: 11 / 255, green: 79 / 255, blue: 138 / 255, alpha: 1)
        static let selectionHaloColor = Color(red: 190 / 255, green: 24 / 255, blue: 93 / 255)
        private static let labelTextColor = UIColor(red: 31 / 255, green: 35 / 255, blue: 40 / 255, alpha: 1)
        
        /// The map displayed in the map view.
        let map: Map
        
        /// The feature table of restaurants in Redlands.
        let restaurantsTable = ServiceFeatureTable(url: .redlandsRestaurants)
        
        /// The feature layer holding the restaurants displayed and identified by the sample.
        let restaurantsLayer: FeatureLayer
        
        /// The overlay for the numbered 1-9 labels.
        let labelOverlay = GraphicsOverlay()
        
        /// Features currently in the area of interest, indexed by the matching number key.
        private(set) var numberedFeatures: [Feature] = []
        
        /// A Boolean value indicating whether more than nine features are selected.
        private(set) var hasMoreThanNineSelectedFeatures = false
        
        init() {
            restaurantsLayer = FeatureLayer(featureTable: restaurantsTable)
            restaurantsLayer.renderer = SimpleRenderer(symbol: Self.restaurantSymbol)
            
            let map = Map(basemapStyle: .arcGISLightGray)
            map.initialViewpoint = Viewpoint(
                center: Point(x: -117.1825, y: 34.0556, spatialReference: .wgs84),
                scale: 5_000
            )
            map.addOperationalLayer(restaurantsLayer)
            self.map = map
        }
        
        /// Selects, numbers, and labels restaurant features intersecting the given envelope.
        func selectFeatures(
            in envelope: Envelope?,
            screenPointForLocation: (Point) -> CGPoint?
        ) async throws {
            restaurantsLayer.clearSelection()
            labelOverlay.removeAllGraphics()
            numberedFeatures.removeAll()
            hasMoreThanNineSelectedFeatures = false
            
            guard let envelope else { return }
            let queryParameters = QueryParameters()
            queryParameters.geometry = envelope
            queryParameters.spatialRelationship = .intersects
            
            let queryResult = try await restaurantsTable.queryFeatures(using: queryParameters)
            let orderedFeatures = queryResult.features()
                .compactMap { feature -> OrderedFeature? in
                    guard let anchor = feature.geometry as? Point,
                          let screenPoint = screenPointForLocation(anchor) else {
                        return nil
                    }
                    return OrderedFeature(feature: feature, anchor: anchor, screenPoint: screenPoint)
                }
                .sorted { lhs, rhs in
                    lhs.screenPoint.y == rhs.screenPoint.y
                    ? lhs.screenPoint.x < rhs.screenPoint.x
                    : lhs.screenPoint.y < rhs.screenPoint.y
                }
            
            hasMoreThanNineSelectedFeatures = orderedFeatures.count > 9
            restaurantsLayer.selectFeatures(orderedFeatures.map(\.feature))
            
            for (offset, orderedFeature) in orderedFeatures.prefix(9).enumerated() {
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
        
        /// Reads the feature's name attribute, returning the fallback when it is missing or blank.
        func name(for feature: Feature, fallback: String?) -> String? {
            if let name = feature.attributes[Self.nameAttribute] as? String,
               !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return name
            } else {
                return fallback
            }
        }
        
        /// The restaurant marker symbol.
        private static var restaurantSymbol: SimpleMarkerSymbol {
            let symbol = SimpleMarkerSymbol(style: .circle, color: markerFillColor, size: 12)
            symbol.outline = SimpleLineSymbol(style: .solid, color: .white, width: 1.5)
            return symbol
        }
    }
    
    /// A feature and its screen-space ordering information.
    struct OrderedFeature {
        let feature: Feature
        let anchor: Point
        let screenPoint: CGPoint
    }
}

private extension URL {
    /// The URL of the Redlands restaurants feature service.
    static var redlandsRestaurants: URL {
        URL(string: "https://services2.arcgis.com/ZQgQTuoyBrtmoGdP/arcgis/rest/services/redlands_food/FeatureServer/0")!
    }
}
