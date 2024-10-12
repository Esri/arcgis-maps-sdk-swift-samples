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

struct AddMapImageLayerView: View {
    /// A map with a map image layer of world elevations.
    @State private var map: Map = {
        // Creates the map image layer using a web URL.
        let url = URL(string: "https://sampleserver5.arcgisonline.com/arcgis/rest/services/Elevation/WorldElevations/MapServer")!
        let mapImageLayer = ArcGISMapImageLayer(url: url)
        
        // Creates the map and adds the layer to the map's operational layers.
        let map = Map()
        map.addOperationalLayer(mapImageLayer)
        
        return map
    }()
    
    var body: some View {
        // Displays the map using a map view.
        MapView(map: map)
    }
}

#Preview {
    AddMapImageLayerView()
}
