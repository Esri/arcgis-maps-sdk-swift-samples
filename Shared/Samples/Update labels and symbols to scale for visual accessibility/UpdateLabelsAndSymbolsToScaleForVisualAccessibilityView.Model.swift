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

extension UpdateLabelsAndSymbolsToScaleForVisualAccessibilityView {
    /// Configures restaurant labeling and scales marker and label symbols
    /// in response to Dynamic Type changes.
    @MainActor
    @Observable
    final class Model {
        /// The marker size in points at the default system text size.
        static let baseMarkerSize: CGFloat = 24
        
        /// The label size in points when system text scaling is disabled or at its default.
        private static let baseLabelSize: CGFloat = 12
        
        /// The label halo width in points when system text scaling is disabled or at its default.
        private static let baseLabelHaloWidth: CGFloat = 2
        
        /// Esri's web style containing the restaurant point symbol.
        private let restaurantSymbolStyle = SymbolStyle(
            styleName: "Esri2DPointSymbolsStyle",
            portal: .arcGISOnline(connection: .anonymous)
        )
        
        /// The layer containing the Redlands restaurants.
        let restaurantsLayer: FeatureLayer
        
        /// Whether restaurant labels follow the system text size.
        var labelsUseSystemTextScale = true {
            didSet {
                updateLabelSize()
            }
        }
        
        /// The current Dynamic Type scale relative to the default body
        /// text size.
        private(set) var systemTextScale: CGFloat = 1
        
        /// The calculated marker size in points.
        var markerSize: CGFloat { Self.baseMarkerSize * systemTextScale }
        
        /// The loaded restaurant symbol whose size follows the system text scale.
        private(set) var markerSymbol: MultilayerPointSymbol?
        
        /// The restaurant label symbol whose size scales when label scaling is enabled.
        private let labelSymbol: TextSymbol
        
        init() {
            restaurantsLayer = FeatureLayer(
                featureTable: ServiceFeatureTable(url: .redlandsRestaurants)
            )
            
            labelSymbol = TextSymbol(
                color: UIColor(
                    red: 31 / 255,
                    green: 35 / 255,
                    blue: 40 / 255,
                    alpha: 1
                ),
                size: Self.baseLabelSize
            )
            labelSymbol.haloColor = .white
            labelSymbol.haloWidth = Self.baseLabelHaloWidth
            let labelDefinition = LabelDefinition(
                labelExpression: ArcadeLabelExpression(
                    arcadeString: "$feature.name"
                ),
                textSymbol: labelSymbol
            )
            labelDefinition.placement = .pointAboveCenter
            // Move labels to avoid overlaps, omitting those that cannot fit.
            labelDefinition.deconflictionStrategy = .dynamic
            restaurantsLayer.addLabelDefinitions([labelDefinition])
            restaurantsLayer.labelsAreEnabled = true
        }
        
        /// Loads the layer and applies the restaurant symbol before displaying it.
        func load() async throws {
            try await restaurantsLayer.load()
            try Task.checkCancellation()
            // Keep the existing renderer and symbol when the view reappears.
            guard markerSymbol == nil else { return }
            try await restaurantSymbolStyle.load()
            try Task.checkCancellation()
            guard let symbol = try await restaurantSymbolStyle.symbol(forKeys: ["restaurant"])
                as? MultilayerPointSymbol else {
                throw RestaurantSymbolError()
            }
            try Task.checkCancellation()
            // Read the latest scale after loading, not the scale at task startup.
            // There is no suspension between sizing and installing the symbol.
            symbol.size = Double(markerSize)
            restaurantsLayer.renderer = SimpleRenderer(symbol: symbol)
            markerSymbol = symbol
        }

        /// Applies Dynamic Type scaling independently to symbols and labels.
        /// - Parameter scale: A multiplier relative to the default Body text
        ///   size, where `1` represents the default size.
        func applySystemTextScale(_ scale: CGFloat) {
            systemTextScale = scale
            // Calculate from the base size to avoid compounding scale changes.
            markerSymbol?.size = Double(markerSize)
            updateLabelSize()
        }
        
        /// Scales labels explicitly because the Swift SDK has no
        /// system-text-scale modifier.
        private func updateLabelSize() {
            // A factor of 1 restores the base label size when scaling is off.
            // Markers continue to follow the system text scale independently.
            let labelScale = labelsUseSystemTextScale ? systemTextScale : 1
            labelSymbol.size = Self.baseLabelSize * labelScale
            // Scale the halo with the text so it stays legible at large sizes.
            labelSymbol.haloWidth = Self.baseLabelHaloWidth * labelScale
        }

        /// An unexpected symbol type returned by the web style.
        struct RestaurantSymbolError: Error {}
    }
}

private extension URL {
    /// The Redlands restaurants feature service.
    static var redlandsRestaurants: URL {
        URL(
            string: "https://services2.arcgis.com/ZQgQTuoyBrtmoGdP"
            + "/arcgis/rest/services/redlands_food/FeatureServer/0"
        )!
    }
}
