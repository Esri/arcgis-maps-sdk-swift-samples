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

struct AddWMSLayerView: View {
    /// A map with light gray basemap centered on the USA.
    @State private var map: Map = {
        let map = Map(basemapStyle: .arcGISLightGrayBase)
        
        // Center the map on the United States.
        map.initialViewpoint = Viewpoint(
            latitude: 39, longitude: -98, scale: 4e7
        )
        
        // A URL to a weather radar WMS service.
        let wmsServiceURL = URL(string: "https://nowcoast.noaa.gov/geoserver/observations/weather_radar/wms")!
        
        // The names of the layers to load at the WMS service.
        let wmsServiceLayerNames = ["conus_base_reflectivity_mosaic"]
        
        // Initialize the WMS layer with the service URL and uniquely identifying
        // WMS layer names.
        let wmsLayer = WMSLayer(url: wmsServiceURL, layerNames: wmsServiceLayerNames)
        
        // Add the WMS layer to the map's operational layers.
        map.addOperationalLayer(wmsLayer)
        return map
    }()
    
    var body: some View {
        // Create a map view to display the map.
        MapView(map: map)
    }
}

#Preview {
    AddWMSLayerView()
}
