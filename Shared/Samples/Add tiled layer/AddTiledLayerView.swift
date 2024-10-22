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

struct AddTiledLayerView: View {
    /// A map with a "World Topographic Map" tiled layer.
    @State private var map: Map = {
        // A web URL to the "World_Topo_Map" map server on ArcGIS Online.
        let worldTopographicMap = URL(
            string: "https://services.arcgisonline.com/arcgis/rest/services/World_Topo_Map/MapServer"
        )!
        
        // Creates a tiled layer using the URL.
        let tiledLayer = ArcGISTiledLayer(url: worldTopographicMap)
        
        // Creates a basemap using the layer.
        let basemap = Basemap(baseLayer: tiledLayer)
        
        // Creates a map using the basemap.
        let map = Map(basemap: basemap)
        
        // Sets the initial viewpoint on the map to zoom in on the layer.
        let extent = Envelope(
            xRange: -18546390...(-1833410),
            yRange: -10740120...18985720,
            spatialReference: .webMercator
        )
        map.initialViewpoint = Viewpoint(boundingGeometry: extent)
        
        return map
    }()
    
    var body: some View {
        // Displays the map using a map view.
        MapView(map: map)
    }
}

#Preview {
    AddTiledLayerView()
}
