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

struct AddTiledLayerAsBasemapView: View {
    /// A map of the streets in San Francisco.
    @State private var map: Map = {
        // Creates a tile cache using a URL to a local tile package file.
        let tileCache = TileCache(fileURL: .sanFranciscoStreetsTilePackage)
        
        // Creates a tiled layer using the tile cache.
        let tiledLayer = ArcGISTiledLayer(tileCache: tileCache)
        
        // Creates a basemap using the layer.
        let basemap = Basemap(baseLayer: tiledLayer)
        
        // Creates a map using the basemap.
        return Map(basemap: basemap)
    }()
    
    var body: some View {
        // Displays the map using a map view.
        MapView(map: map)
    }
}

private extension URL {
    /// The URL to the local tile package file with street data for San Francisco, CA, USA.
    static var sanFranciscoStreetsTilePackage: URL {
        Bundle.main.url(forResource: "SanFrancisco", withExtension: "tpkx")!
    }
}
