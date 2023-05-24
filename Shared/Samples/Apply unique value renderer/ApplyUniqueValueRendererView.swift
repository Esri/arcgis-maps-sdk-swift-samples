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
    
    /// A map with topographic basemap.
    @State private var map: Map = {
        let map = Map(basemapStyle: .arcGISTopographic)
        let centerPoint = Point(x: -12966000.5, y: 4441498.5, spatialReference: .webMercator)
        map.initialViewpoint = Viewpoint(center: centerPoint, scale: 4e7)
        
        return map
    }()
    
    /// Creates a unique value renderer configured to render California as red,
    /// Arizona as green, and Nevada as blue.
    private func makeUniqueValueRenderer() -> UniqueValueRenderer {
        // Instantiate a new unique value renderer
        let renderer = UniqueValueRenderer()
        
        // Set the field to use for the unique values
        // (You can add multiple fields to be used for the renderer in the form of a list, in this case we are only adding a single field)
        renderer.addFieldNames(["STATE_ABBR"])
            
        // Create symbols to be used in the renderer
        let defaultSymbol = SimpleFillSymbol(color: .clear, outline: SimpleLineSymbol(style: .solid, color: .gray, width: 2))
        let californiaSymbol = SimpleFillSymbol(style: .solid, color: .red, outline: SimpleLineSymbol(style: .solid, color: .red, width: 2))
        let arizonaSymbol = SimpleFillSymbol(style: .solid, color: .green, outline: SimpleLineSymbol(style: .solid, color: .green, width: 2))
        let nevadaSymbol = SimpleFillSymbol(style: .solid, color: .blue, outline: SimpleLineSymbol(style: .solid, color: .blue, width: 2))
            
        // Set the default symbol
        renderer.defaultSymbol = defaultSymbol
        renderer.defaultLabel = "Other"
            
        // Create unique values
        let californiaValue = UniqueValue(description: "State of California", label: "California", symbol: californiaSymbol, values: ["CA"])
        let arizonaValue = UniqueValue(description: "State of Arizona", label: "Arizona", symbol: arizonaSymbol, values: ["AZ"])
        let nevadaValue = UniqueValue(description: "State of Nevada", label: "Nevada", symbol: nevadaSymbol, values: ["NV"])
            
        // Add the values to the renderer
        renderer.addUniqueValues([californiaValue, arizonaValue, nevadaValue])
            
        return renderer
        }
    
    var body: some View {
        // Creates a map view to display the map.
        MapView(map: map)
            .task {
                guard map.operationalLayers.isEmpty else { return }
                do {
                    // Create feature layer
                    let featureTable = ServiceFeatureTable(url: URL(
                        string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/Census/MapServer/3")!
                    )
                    let featureLayer = FeatureLayer(featureTable: featureTable)
                    // Load feature layer
                    try await featureLayer.load()
                    // Make unique value renderer and assign it to the feature layer
                    featureLayer.renderer = makeUniqueValueRenderer()
                    // Add the layer to the map as operational layer
                    map.addOperationalLayer(featureLayer)
                } catch {
                    // Presents an error message if the URL fails to load.
                    self.error = error
                }
            }
            .alert(isPresented: $isShowingAlert, presentingError: error)
    }
}
