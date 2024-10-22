// Copyright 2024 Esri
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

struct DisplayAlternateSymbolsAtDifferentScalesView: View {
    /// A map with a layer of the incidents in San Francisco, CA.
    @State private var map: Map = {
        let map = Map(basemapStyle: .arcGISTopographic)
        
        // Creates the feature layer from a URL and adds it to the map.
        let featureTable = ServiceFeatureTable(url: .sf311IncidentsLayer)
        let featureLayer = FeatureLayer(featureTable: featureTable)
        map.addOperationalLayer(featureLayer)
        
        // Sets the render on the feature layer.
        featureLayer.renderer = makeUniqueValueRenderer()
        
        let center = Point(x: -13631200, y: 4546830, spatialReference: .webMercator)
        map.initialViewpoint = Viewpoint(center: center, scale: 7_500)
        
        return map
    }()
    
    /// The current viewpoint of the map view.
    @State private var viewpoint: Viewpoint?
    
    var body: some View {
        MapView(map: map, viewpoint: viewpoint)
            .onViewpointChanged(kind: .centerAndScale) { newViewpoint in
                viewpoint = newViewpoint
            }
            .overlay(alignment: .top) {
                Text("Scale: 1:\(viewpoint?.targetScale ?? 0, format: .number.rounded(increment: 1))")
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(8)
                    .background(.regularMaterial, ignoresSafeAreaEdges: .horizontal)
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button("Reset Viewpoint") {
                        viewpoint = map.initialViewpoint
                    }
                }
            }
    }
    
    /// Creates a unique value renderer with alternate symbols for different scales.
    /// - Returns: A new `UniqueValueRenderer` object.
    private static func makeUniqueValueRenderer() -> UniqueValueRenderer {
        // The multilayer symbol for the low range scale.
        let redTriangle = SimpleMarkerSymbol(style: .triangle, color: .red, size: 30)
            .toMultilayerSymbol()
        redTriangle.referenceProperties = SymbolReferenceProperties(minScale: 5_000, maxScale: 0)
        
        // The alternate multilayer symbol for the mid range scale.
        let blueSquare = SimpleMarkerSymbol(style: .square, color: .blue, size: 30)
            .toMultilayerSymbol()
        blueSquare.referenceProperties = SymbolReferenceProperties(minScale: 10_000, maxScale: 5_000)
        
        // The alternate multilayer symbol for the high range scale.
        let yellowDiamond = SimpleMarkerSymbol(style: .diamond, color: .yellow, size: 30)
            .toMultilayerSymbol()
        yellowDiamond.referenceProperties = SymbolReferenceProperties(minScale: 20_000, maxScale: 10_000)
        
        let uniqueValue = UniqueValue(
            description: "unique values based on request type",
            label: "unique value",
            symbol: redTriangle,
            values: ["Damaged Property"],
            alternateSymbols: [blueSquare, yellowDiamond]
        )
        
        // The default symbol for values that don’t match the unique values.
        let purpleDiamond = SimpleMarkerSymbol(style: .diamond, color: .purple, size: 15)
            .toMultilayerSymbol()
        
        return UniqueValueRenderer(
            fieldNames: ["req_type"],
            uniqueValues: [uniqueValue],
            defaultSymbol: purpleDiamond
        )
    }
}

private extension URL {
    /// The web URL to the SF311 feature service "Incidents" layer on ArcGIS Online.
    static var sf311IncidentsLayer: URL {
        URL(string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/SF311/FeatureServer/0")!
    }
}

#Preview {
    DisplayAlternateSymbolsAtDifferentScalesView()
}
