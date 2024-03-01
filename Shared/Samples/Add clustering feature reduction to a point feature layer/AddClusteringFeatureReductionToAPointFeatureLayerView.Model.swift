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
import UIKit.UIColor

extension ConfigureClustersView {
    /// The model used to store the geo model and other expensive objects
    /// used in this view.
    class Model: ObservableObject {
        /// A Zurich buildings web map.
        let map = Map(
            item: PortalItem(
                portal: .arcGISOnline(connection: .anonymous),
                id: .zurichBuildings
            )
        )
        
        /// A custom feature reduction for dynamically aggregating and
        /// summarizing groups of features as the map scale changes.
        private let clusteringFeatureReduction = makeCustomFeatureReduction(renderer: makeClassBreaksRenderer())
        
        /// The buildings feature layer in the web map.
        var featureLayer: FeatureLayer? {
            map.operationalLayers.first as? FeatureLayer
        }
        
        /// A Boolean value indicating whether cluster labels are displayed.
        var showsLabels: Bool {
            didSet {
                clusteringFeatureReduction.showsLabels = showsLabels
            }
        }
        
        /// The maximum scale of feature clusters.
        /// - Note: The default value for max scale is 0.
        var maxScale: Double {
            didSet {
                clusteringFeatureReduction.maxScale = maxScale
            }
        }
        
        /// The radius of feature clusters.
        /// - Note: The default value for cluster radius is 60.
        /// Larger radius allows more features to be grouped into a cluster.
        var radius: Double {
            didSet {
                clusteringFeatureReduction.radius = radius
            }
        }
        
        init() {
            // Set initial values for controls.
            showsLabels = clusteringFeatureReduction.showsLabels
            radius = clusteringFeatureReduction.radius
            maxScale = clusteringFeatureReduction.maxScale ?? .zero
        }
        
        /// Loads the web map and set up the feature layer.
        func setup() async throws {
            try await map.load()
            featureLayer?.featureReduction = clusteringFeatureReduction
        }
        
        /// Creates a class breaks renderer for the custom feature reduction
        /// - Returns: A `ClassBreaksRenderer` object.
        private static func makeClassBreaksRenderer() -> ClassBreaksRenderer {
            // For each feature cluster with a given average building height,
            // a color is assigned to each symbol.
            let colors = [
                (4, 251, 255),
                (44, 211, 255),
                (74, 181, 255),
                (120, 135, 255),
                (165, 90, 255),
                (194, 61, 255),
                (224, 31, 255),
                (254, 1, 255)
            ].map {
                UIColor(red: $0.0 / 255, green: $0.1 / 255, blue: $0.2 / 255, alpha: 1)
            }
            
            // Create a class break and a symbol to display the features
            // in each value range.
            // In this case, the average building height ranges from 0 to 7 stories.
            let classBreaks = zip([Int](0...7), colors).map { value, color in
                ClassBreak(
                    description: "\(value) floor",
                    label: String(value),
                    minValue: Double(value),
                    maxValue: Double(value) + 1,
                    symbol: SimpleMarkerSymbol(color: color)
                )
            }
            
            // Create a class breaks renderer to apply to the custom
            // feature reduction.
            // Define the field to use for the class breaks renderer.
            // Note that this field name must match the name of an
            // aggregate field contained in the clustering feature reduction's
            // aggregate fields property.
            let renderer = ClassBreaksRenderer(fieldName: "Average Building Height", classBreaks: classBreaks)
            
            // Create a default symbol for features that do not fall within
            // any of the ranges defined by the class breaks.
            renderer.defaultSymbol = SimpleMarkerSymbol(color: .systemPink)
            
            return renderer
        }
        
        /// Creates a custom feature reduction for the sample.
        /// - Parameter renderer: A renderer for drawing clustered features.
        /// - Returns: A `ClusteringFeatureReduction` object.
        private static func makeCustomFeatureReduction(renderer: ClassBreaksRenderer) -> ClusteringFeatureReduction {
            // Create a new clustering feature reduction using the
            // class breaks renderer.
            let clusteringFeatureReduction = ClusteringFeatureReduction(renderer: renderer)
            
            // Set the feature reduction's aggregate fields.
            // Note that the field names must match those in the feature layer.
            // The aggregate fields summarize values based on the defined
            // aggregate statistic type.
            clusteringFeatureReduction.addAggregateFields([
                AggregateField(
                    name: "Total Residential Buildings",
                    statisticFieldName: "Residential_Buildings",
                    statisticType: .sum
                ),
                AggregateField(
                    name: "Average Building Height",
                    statisticFieldName: "Most_common_number_of_storeys",
                    statisticType: .mode
                )
            ])
            
            // Enable the feature reduction.
            clusteringFeatureReduction.isEnabled = true
            
            // Set the popup definition for the custom feature reduction.
            clusteringFeatureReduction.popupDefinition = PopupDefinition(popupSource: clusteringFeatureReduction)
            
            // Set values for the feature reduction's cluster minimum
            // and maximum symbol sizes. Note that the default values
            // for max and min symbol size are 70 and 12 respectively.
            clusteringFeatureReduction.minSymbolSize = 5
            clusteringFeatureReduction.maxSymbolSize = 90
            
            // Create a label definition with a simple label expression.
            let labelDefinition = LabelDefinition(
                labelExpression: SimpleLabelExpression(simpleExpression: "[cluster_count]"),
                textSymbol: TextSymbol(color: .black, size: 15)
            )
            labelDefinition.placement = .pointCenterCenter
            
            // Add the label definition to the feature reduction.
            clusteringFeatureReduction.addLabelDefinition(labelDefinition)
            
            return clusteringFeatureReduction
        }
    }
}

private extension PortalItem.ID {
    /// The ID used in the Zurich buildings web map.
    static var zurichBuildings: Self { Self("aa44e79a4836413c89908e1afdace2ea")! }
}
