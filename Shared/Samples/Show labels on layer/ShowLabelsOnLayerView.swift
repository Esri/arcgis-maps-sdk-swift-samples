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
    /// A map with a light gray canvas basemap centered on the USA.
    @State private var map: Map = {
        let map = Map(basemapStyle: .arcGISLightGrayBase)
        map.initialViewpoint = Viewpoint(
            center: Point(x: -10626699.4, y: 2150308.5),
            scale: 74016655.9
        )
        return map
    }()
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    var body: some View {
        MapView(map: map)
            .task {
                do {
                    // Create a portal item from an id.
                    let portalItem = PortalItem(
                        portal: .arcGISOnline(connection: .anonymous),
                        id: .usaCongressionalDistricts
                    )
                    
                    try await portalItem.load()
                    
                    // Create a feature layer from the portal item.
                    let featureLayer = FeatureLayer(item: portalItem)
                    
                    // Add the layer to the map.
                    map.addOperationalLayer(featureLayer)
                    
                    // Add labels to the layer.
                    addLabels(to: featureLayer)
                } catch {
                    // Present an error if feature table fails to load.
                    self.error = error
                }
            }
            .errorAlert(presentingError: $error)
    }
}

private extension ShowLabelsOnLayerView {
    /// Adds labels to a feature layer.
    /// - Parameter layer: The `FeatureLayer` to add the labels to.
    func addLabels(to layer: FeatureLayer) {
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
        let textSymbol = TextSymbol(color: color, size: 12)
        textSymbol.haloColor = .white
        textSymbol.haloWidth = 2
        
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

private extension PortalItem.ID {
    /// An id for a USA Congressional Districts Analysis feature table.
    static var usaCongressionalDistricts: Self { Self("cc6a869374434bee9fefad45e291b779 ")! }
}

#Preview {
    ShowLabelsOnLayerView()
}
