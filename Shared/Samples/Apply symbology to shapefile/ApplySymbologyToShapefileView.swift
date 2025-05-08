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

struct ApplySymbologyToShapefileView: View {
    /// The map that will contain our shapefile.
    @State private var map = {
        // Create a map with a topographic basemap.
        let map = Map(basemapStyle: .arcGISTopographic)
        
        // Set an initial viewpoint.
        map.initialViewpoint = Viewpoint(
            center: Point(x: -11662054, y: 4818336, spatialReference: .webMercator),
            scale: 200_000
        )
        
        // Create a shapefile feature table.
        let featureTable = ShapefileFeatureTable(
            fileURL: Bundle.main.url(forResource: "Subdivisions", withExtension: "shp", subdirectory: "Aurora_CO_shp")!
        )
        
        // And now create a layer from that shapefile feature table.
        let layer = FeatureLayer(featureTable: featureTable)
        
        // Setup the symbology.
        let lineSymbol = SimpleLineSymbol(style: .solid, color: .red, width: 1.0)
        let fillSymbol = SimpleFillSymbol(style: .solid, color: .yellow, outline: lineSymbol)
        
        // Create a renderer and specify our symbology for that renderer.
        layer.renderer = SimpleRenderer(symbol: fillSymbol)
        
        // Add the feature layer to the map.
        map.addOperationalLayer(layer)
        return map
    }()
    
    var body: some View {
        MapView(map: map)
    }
}

#Preview {
    ApplySymbologyToShapefileView()
}
