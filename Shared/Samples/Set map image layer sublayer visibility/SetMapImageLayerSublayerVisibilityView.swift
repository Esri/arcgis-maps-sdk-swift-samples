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

struct SetMapImageLayerSublayerVisibilityView: View {
    @State private var map: Map = {
        // Makes a new map with an oceans basemap style.
        let map = Map(basemapStyle: .arcGISOceans)
        return map
    }()
    
    @State private var imageLayer: ArcGISMapImageLayer = {
        let imageLayer = ArcGISMapImageLayer(url:  URL(string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/SampleWorldCities/MapServer")!)
        return imageLayer
    }()
    
    init() {
        map.addOperationalLayer(imageLayer)
    }
    
    var body: some View {
        MapViewReader { mapViewProxy in
            MapView(map: map)
        }
    }
}
