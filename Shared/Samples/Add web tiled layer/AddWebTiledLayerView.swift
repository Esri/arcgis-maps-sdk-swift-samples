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

struct AddWebTiledLayerView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    var body: some View {
        VStack {
            MapView(map: model.map)
        }
    }
}

private extension AddWebTiledLayerView {
    // MARK: - Model
    
    /// The view model for the sample.
    final class Model: ObservableObject {
        @Published var map: Map
        
        init() {
            self.map = Model.makeMap()
        }
        
        /// A map with a web tiled layer as basemap.
        static func makeMap() -> Map {
            let webTiledLayer = webTiledLayer()
            let basemap = Basemap(baseLayer: webTiledLayer)
            let map = Map(basemap: basemap)
            return map
        }
        
        static func webTiledLayer() -> WebTiledLayer {
            let  worldTileServiceURL = "https://server.arcgisonline.com/arcgis/rest/services/Ocean/World_Ocean_Base/MapServer/tile/{level}/{row}/{col}.jpg"
            
            let attribution = """
                Map tiles by <a href="https://livingatlas.arcgis.com">ArcGIS Living Atlas of the World</a>, under <a href="https://www.esri.com/en-us/legal/terms/full-master-agreement">Esri Master License Agreement</a>. Data by Esri, Garmin, GEBCO, NOAA NGDC, and other contributors.
                """
            
            // Build the web tiled layer from ArcGIS Living Atlas of the World tile service url.
            let webTiledLayer = WebTiledLayer(urlTemplate: worldTileServiceURL)
            // Set the attribution on the layer.
            webTiledLayer.setAttribution(attribution)
            
            return webTiledLayer
        }
    }
}

#Preview {
    AddWebTiledLayerView()
}
