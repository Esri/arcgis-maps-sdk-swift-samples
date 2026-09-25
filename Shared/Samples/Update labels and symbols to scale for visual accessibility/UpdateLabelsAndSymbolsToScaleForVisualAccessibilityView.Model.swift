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
    @MainActor
    @Observable
    final class Model {
        /// The map displayed in the map view.
        let map: Map
        
        /// The layer containing the Redlands restaurants.
        let restaurantsLayer: FeatureLayer
        
        /// The dark blue color shared by the restaurant markers and legend.
        static let markerColor = UIColor(
            red: 11 / 255,
            green: 79 / 255,
            blue: 138 / 255,
            alpha: 1
        )
        
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
        var markerSize: CGFloat { 12 * systemTextScale }
        
        /// The restaurant marker and label symbols, sized in points.
        private let markerSymbol: SimpleMarkerSymbol
        private let labelSymbol: TextSymbol
        
        init() {
            map = Map(basemapStyle: .arcGISLightGray)
            map.initialViewpoint = Viewpoint(
                latitude: 34.0556,
                longitude: -117.1793,
                scale: 2_500
            )
            markerSymbol = SimpleMarkerSymbol(
                style: .circle,
                color: Self.markerColor,
                size: 12
            )
            markerSymbol.outline = SimpleLineSymbol(
                style: .solid,
                color: .white,
                width: 1.5
            )
            restaurantsLayer = FeatureLayer(
                featureTable: ServiceFeatureTable(url: .redlandsRestaurants)
            )
            restaurantsLayer.renderer = SimpleRenderer(symbol: markerSymbol)
            
            labelSymbol = TextSymbol(
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
            labelDefinition.deconflictionStrategy = .noDeconfliction
            restaurantsLayer.addLabelDefinitions([labelDefinition])
            restaurantsLayer.labelsAreEnabled = true
            map.addOperationalLayer(restaurantsLayer)
        }
        
        /// Applies Dynamic Type scaling independently to symbols and labels.
        func applySystemTextScale(_ scale: CGFloat) {
            systemTextScale = scale
            // Calculate from the base size to avoid compounding scale changes.
            markerSymbol.size = markerSize
            markerSymbol.outline?.width = 1.5 * scale
            updateLabelSize()
        }
        
        /// Scales labels explicitly because the Swift SDK has no
        /// system-text-scale modifier.
        private func updateLabelSize() {
            labelSymbol.size = 12 * (
                labelsUseSystemTextScale ? systemTextScale : 1
            )
        }
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
