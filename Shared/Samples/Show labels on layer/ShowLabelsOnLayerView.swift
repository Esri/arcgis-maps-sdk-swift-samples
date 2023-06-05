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

struct ShowLabelsOnLayerView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    var body: some View {
        // Create a map view to display the map.
        MapView(map: model.map)
            .alert(isPresented: $model.isShowingAlert, presentingError: model.alertError)
    }
}

private extension ShowLabelsOnLayerView {
    /// The view model for the sample.
    class Model: ObservableObject {
        /// A map with a light gray canvas basemap with a USA congressional
        /// districts feature layer and labels.
        var map: Map!
        
        /// A Boolean value indicating whether to show an alert.
        @Published var isShowingAlert = false
        
        /// The error shown in the alert.
        @Published var alertError: Error? {
            didSet { isShowingAlert = alertError != nil }
        }
        
        init() {
            map = makeMap()
        }
        
        /// Create a map with a feature layer and labels.
        /// - Returns: A new `Map` object.
        private func makeMap() -> Map {
            // Create a map with a light gray canvas basemap.
            let map = Map(basemapStyle: .arcGISLightGrayBase)
            map.initialViewpoint = Viewpoint(
                center: Point(x: -10626699.4, y: 2150308.5),
                scale: 74016655.9
            )
            
            // Create a feature table from the URL.
            let featureTable = ServiceFeatureTable(url: .usaCongressionalDistricts)
            
            // Present error if feature table fails to load.
            Task {
                do {
                    try await featureTable.load()
                } catch {
                    alertError = error
                }
            }
            
            // Create a feature layer from the table.
            let featureLayer = FeatureLayer(featureTable: featureTable)
            
            // Add the layer to the map.
            map.addOperationalLayer(featureLayer)
            
            // Add labels to the layer.
            addLabels(to: featureLayer)
            
            return map
        }
        
        /// Add labels to a feature layer.
        /// - Parameter layer: The `FeatureLayer` to add the labels to.
        private func addLabels(to layer: FeatureLayer) {
            // Create label definitions for the two groups.
            let democratDefinition = makeLabelDefinition(party: "Democrat", color: .blue)
            let republicanDefinition = makeLabelDefinition(party: "Republican", color: .red)
            
            // Add the label definitions to the layer.
            layer.addLabelDefinitions([democratDefinition, republicanDefinition])
            
            // Turn on labeling.
            layer.labelsAreEnabled = true
        }
        
        /// Creates a label definition for the given PARTY field value and color.
        /// - Parameters:
        ///   - party: A `String` representing the party.
        ///   - color: The `UIColor` for the label.
        /// - Returns: A new `LabelDefinition` object.
        private func makeLabelDefinition(party: String, color: UIColor) -> LabelDefinition {
            // The styling for the label.
            let textSymbol = TextSymbol()
            textSymbol.size = 12
            textSymbol.haloColor = .white
            textSymbol.haloWidth = 2
            textSymbol.color = color
            
            // An SQL WHERE statement for filtering the features this label applies to.
            let whereStatement = "PARTY = '\(party)'"
            
            // An expression that specifies the content of the label using the table's attributes.
            let expression = "$feature.NAME + ' (' + left($feature.PARTY,1) + ')\\nDistrict' + $feature.CDFIPS"
            
            // Make an arcade label expression.
            let arcadeLabelExpression = ArcadeLabelExpression(arcadeString: expression)
            let labelDefinition = LabelDefinition(labelExpression: arcadeLabelExpression, textSymbol: textSymbol)
            labelDefinition.placement = .polygonAlwaysHorizontal
            labelDefinition.whereClause = whereStatement
            
            return labelDefinition
        }
    }
}

private extension URL {
    /// A feature table URL for a USA Congressional Districts Analysis.
    static var usaCongressionalDistricts: URL {
        URL(string: "https://services.arcgis.com/P3ePLMYs2RVChkJx/arcgis/rest/services/USA_Congressional_Districts_analysis/FeatureServer/0")!
    }
}
