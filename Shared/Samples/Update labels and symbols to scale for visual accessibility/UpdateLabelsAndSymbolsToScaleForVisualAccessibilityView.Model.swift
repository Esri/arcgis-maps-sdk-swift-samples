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
import Observation
import UIKit

@available(macCatalyst, unavailable)
extension UpdateLabelsAndSymbolsToScaleForVisualAccessibilityView {
    /// Configures restaurant labeling and scales marker symbols
    /// in response to Dynamic Type changes.
    @available(macCatalyst, unavailable)
    @MainActor
    @Observable
    final class Model {
        /// A map displaying restaurants in Redlands, California.
        let map: Map = {
            let map = Map(basemapStyle: .arcGISLightGray)
            map.initialViewpoint = Viewpoint(
                latitude: 34.0556,
                longitude: -117.1793,
                scale: 2_500
            )
            return map
        }()
        
        /// A Boolean value indicating whether the restaurant layer and symbols are loading.
        private(set) var isLoading = true

        /// Identifies the most recent view-lifetime load operation.
        private var loadID: UUID?
        
        /// The marker size in points at the default system text size.
        static let baseMarkerSize: Double = 24
        
        /// Esri's web style containing the restaurant point symbol.
        private let restaurantSymbolStyle = SymbolStyle(
            styleName: "Esri2DPointSymbolsStyle",
            portal: .arcGISOnline(connection: .anonymous)
        )
        
        /// The layer containing the Redlands restaurants.
        let restaurantsLayer: FeatureLayer
        
        /// A Boolean value indicating whether restaurant labels follow the system text size.
        var labelsUseSystemTextScale = true
        
        /// The current Dynamic Type scale relative to the default body
        /// text size.
        private(set) var systemTextScale: Double = 1
        
        /// The calculated marker size in points.
        var markerSize: Double { Self.baseMarkerSize * systemTextScale }
        
        /// The loaded restaurant symbol whose size follows the system text scale.
        private(set) var markerSymbol: MultilayerPointSymbol?
        
        init() {
            restaurantsLayer = FeatureLayer(
                featureTable: ServiceFeatureTable(url: .redlandsRestaurants)
            )
        }

        /// Adds the sample's label definition to the loaded feature layer.
        private func configureLabels() {
            let labelSymbol = TextSymbol(
                color: UIColor(
                    red: 31 / 255,
                    green: 35 / 255,
                    blue: 40 / 255,
                    alpha: 1
                ),
                size: 12
            )
            labelSymbol.haloColor = .white
            labelSymbol.haloWidth = 2
            let labelDefinition = LabelDefinition(
                labelExpression: ArcadeLabelExpression(
                    arcadeString: "$feature.name"
                ),
                textSymbol: labelSymbol
            )
            labelDefinition.placement = .pointAboveCenter
            // Keep the preferred position even when labels overlap.
            labelDefinition.deconflictionStrategy = .noDeconfliction
            restaurantsLayer.addLabelDefinitions([labelDefinition])
            restaurantsLayer.labelsAreEnabled = true
        }
        
        /// Loads the layer and applies the restaurant symbol before displaying it.
        func load() async throws {
            try Task.checkCancellation()
            let loadID = UUID()
            self.loadID = loadID
            isLoading = true
            defer {
                if self.loadID == loadID { isLoading = false }
            }
            try await restaurantsLayer.retryLoad()
            try Task.checkCancellation()
            guard self.loadID == loadID else { return }
            // Keep the existing renderer and symbol when the view reappears.
            if markerSymbol == nil {
                try await restaurantSymbolStyle.retryLoad()
                try Task.checkCancellation()
                guard self.loadID == loadID else { return }
                guard let symbol = try await restaurantSymbolStyle.symbol(forKeys: ["restaurant"]) as? MultilayerPointSymbol else {
                    throw RestaurantSymbolError()
                }
                try Task.checkCancellation()
                guard self.loadID == loadID else { return }
                // Read the latest scale after loading, not the scale at task startup.
                // There is no suspension between sizing and installing the symbol.
                symbol.size = markerSize
                configureLabels()
                restaurantsLayer.renderer = SimpleRenderer(symbol: symbol)
                markerSymbol = symbol
            }
            try Task.checkCancellation()
            // Display only the configured layer, and don't add it twice.
            if map.operationalLayers.isEmpty {
                map.addOperationalLayer(restaurantsLayer)
            }
        }
        
        /// Applies Dynamic Type scaling to marker symbols independently of label scaling.
        /// - Parameter scale: A multiplier relative to the default Body text
        ///   size, where `1` represents the default size.
        func applySystemTextScale(_ scale: Double) {
            systemTextScale = scale
            // Calculate from the base size to avoid compounding scale changes.
            markerSymbol?.size = markerSize
        }
        
        /// An unexpected symbol type returned by the web style.
        struct RestaurantSymbolError: LocalizedError {
            var errorDescription: String? {
                "The web style did not return a restaurant point symbol."
            }
        }
    }
}

private extension URL {
    /// The Redlands restaurants feature service.
    static var redlandsRestaurants: URL {
        URL(
            string: "https://services2.arcgis.com/ZQgQTuoyBrtmoGdP/arcgis/rest/services/redlands_food/FeatureServer/0"
        )!
    }
}
