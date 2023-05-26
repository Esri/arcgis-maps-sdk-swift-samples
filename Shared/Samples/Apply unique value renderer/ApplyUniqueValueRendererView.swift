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

struct ApplyUniqueValueRendererView: View {
    /// A Boolean value indicating whether to show an alert.
    @State private var isShowingAlert = false
    
    /// The error shown in the alert.
    @State private var error: Error? {
        didSet { isShowingAlert = error != nil }
    }
    
    /// A map with topographic basemap centered on western United States.
    @State private var map: Map = {
        let map = Map(basemapStyle: .arcGISTopographic)
        let centerPoint = Point(x: -12356253.6, y: 3842795.4, spatialReference: .webMercator)
        map.initialViewpoint = Viewpoint(center: centerPoint, scale: 52681563.2)
        return map
    }()
    
    /// Creates a unique value renderer configured to render the Pacific states
    /// as blue, the Mountain states as green, and the West South Central states
    /// as brown.
    private func makeUniqueValueRenderer() -> UniqueValueRenderer {
        // Instantiate a new unique value renderer.
        let regionRenderer = UniqueValueRenderer()
        
        // Add the "SUB_REGION" field to the renderer.
        regionRenderer.addFieldNames(["SUB_REGION"])
        
        // Define a line symbol to use for the region fill symbol outlines.
        let stateOutlineSymbol = SimpleLineSymbol(style: .solid, color: .white, width: 0.7)
        
        // Define distinct fill symbols for the regions (use the same outline symbol).
        let pacificFillSymbol = SimpleFillSymbol(style: .solid, color: .blue, outline: stateOutlineSymbol)
        let mountainFillSymbol = SimpleFillSymbol(style: .solid, color: .green, outline: stateOutlineSymbol)
        let westSouthCentralFillSymbol = SimpleFillSymbol(style: .solid, color: .brown, outline: stateOutlineSymbol)
            
        // Create unique values.
        let pacificValue = UniqueValue(description: "Pacific Region", label: "Pacific", symbol: pacificFillSymbol, values: ["Pacific"])
        let mountainValue = UniqueValue(description: "Rocky Mountain Region", label: "Mountain", symbol: mountainFillSymbol, values: ["Mountain"])
        let westSouthCentralValue = UniqueValue(description: "West South Central Region", label: "West South Central", symbol: westSouthCentralFillSymbol, values: ["West South Central"])
        
        // Set the default region fill symbol for regions not explicitly defined in the renderer.
        let defaultFillSymbol = SimpleFillSymbol(style: .cross, color: .gray)
        regionRenderer.defaultSymbol = defaultFillSymbol
        regionRenderer.defaultLabel = "Other"
            
        // Add the values to the renderer.
        regionRenderer.addUniqueValues([pacificValue, mountainValue, westSouthCentralValue])
        return regionRenderer
        }
    
    var body: some View {
        // Create a map view to display the map.
        MapView(map: map)
            .task {
                do {
                    // Create URL to the census feature service.
                    let serviceURL = URL(string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/Census/MapServer/3")!
                    
                    // Create service feature table.
                    let featureTable = ServiceFeatureTable(url: serviceURL)
                    
                    // Create a new feature layer using the service feature table.
                    let featureLayer = FeatureLayer(featureTable: featureTable)
                    
                    // Make unique value renderer and assign it to the feature layer.
                    featureLayer.renderer = makeUniqueValueRenderer()
                    
                    // Load feature layer.
                    try await featureLayer.load()
                    
                    // Add the layer to the map as operational layer.
                    map.addOperationalLayer(featureLayer)
                } catch {
                    // Present an error message if the URL fails to load.
                    self.error = error
                }
            }
            .alert(isPresented: $isShowingAlert, presentingError: error)
    }
}
