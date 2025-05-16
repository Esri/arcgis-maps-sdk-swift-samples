// Copyright 2025 Esri
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

struct ShowLabelsOnLayerIn3DView: View {
    /// A scene with a scene layer of utilities infrastructure in New York City.
    @State private var scene: ArcGIS.Scene = Scene(
        item: PortalItem(
            portal: .arcGISOnline(connection: .anonymous),
            id: .newYorkCityInfrastructure
        )
    )
    
    /// The gas network feature layer on the scene.
    private var gasFeatureLayer: FeatureLayer {
        let groupLayer = scene.operationalLayers.first(where: { $0.name == "Gas" }) as! GroupLayer
        return groupLayer.layers.first(where: { $0.name == "Gas Main" }) as! FeatureLayer
    }
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    var body: some View {
        SceneView(scene: scene)
            .task {
                do {
                    try await scene.load()
                    addLabels(to: gasFeatureLayer)
                } catch {
                    self.error = error
                }
            }
            .errorAlert(presentingError: $error)
    }
}

private extension ShowLabelsOnLayerIn3DView {
    /// Adds labels to a feature layer.
    /// - Parameter layer: The `FeatureLayer` to add the labels to.
    func addLabels(to layer: FeatureLayer) {
        // Create a label definition.
        let labelDefinition = makeLabelDefinition()
        
        // Add label definition to the layer.
        layer.addLabelDefinition(labelDefinition)
        
        // Turn on labeling.
        layer.labelsAreEnabled = true
    }
    
    /// Creates a label definition
    func makeLabelDefinition() -> LabelDefinition {
        // The styling for the label.
        let textSymbol = TextSymbol(color: .orange, size: 16)
        textSymbol.haloColor = .white
        textSymbol.haloWidth = 2
        
        // Make an arcade label expression.
        let arcadeLabelExpression = ArcadeLabelExpression(arcadeString: "Text($feature.INSTALLATIONDATE, `DD MMM YY`)")
        let labelDefinition = LabelDefinition(labelExpression: arcadeLabelExpression, textSymbol: textSymbol)
        labelDefinition.placement = .lineAboveAlong
        labelDefinition.usesCodedValues = true
        
        return labelDefinition
    }
}

private extension PortalItem.ID {
    /// The ID to the "New York City infrastructure with 3D labels" web scene portal item on ArcGIS Online.
    static var newYorkCityInfrastructure: Self { Self("850dfee7d30f4d9da0ebca34a533c169 ")! }
}

#Preview {
    ShowLabelsOnLayerIn3DView()
}
