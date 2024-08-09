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
    /// A map with web tiled layer.
    @State private var map: Map = {
        // Build the web tiled layer from ArcGIS Living Atlas of the World tile service url.
        let webTiledLayer = WebTiledLayer(urlTemplate: .worldTileServiceStringURL)
        webTiledLayer.setAttribution(.attributionString)
        
        let basemap = Basemap(baseLayer: webTiledLayer)
        let map = Map(basemap: basemap)
        map.initialViewpoint = Viewpoint(
            center: Point(x: -1e6, y: 1e6),
            scale: 15e7
        )
        return map
    }()
    
    var body: some View {
        MapView(map: map)
    }
}

private extension String {
    /// The attribution string for the ArcGIS Living Atlas of the World.
    static let attributionString = """
        Map tiles by <a href="https://livingatlas.arcgis.com">ArcGIS Living Atlas of the World</a>, under <a href="https://www.esri.com/en-us/legal/terms/full-master-agreement">Esri Master License Agreement</a>. Data by Esri, Garmin, GEBCO, NOAA NGDC, and other contributors.
        """
    /// The web tile service url from ArcGIS Living Atlas of the World.
    static let worldTileServiceStringURL = "https://services.arcgisonline.com/ArcGIS/rest/services/Ocean/World_Ocean_Base/MapServer/tile/{level}/{row}/{col}.jpg"
}

#Preview {
    AddWebTiledLayerView()
}
