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
    /// A Boolean value indicating whether to show an alert.
    @State private var isShowingAlert = false
    
    /// The error shown in the alert.
    @State private var error: Error? {
        didSet { isShowingAlert = error != nil }
    }
    
    /// A map with light gray basemap centered on the USA.
    @State private var map: Map = {
        let map = Map(basemapStyle: .arcGISLightGrayBase)
        map.initialViewpoint = Viewpoint(
            latitude: 39, longitude: -98, scale: 3.6978595474472E7
        )
        return map
    }()
    
    var body: some View {
        // Creates a map view to display the map.
        MapView(map: map)
            .task {
                guard map.operationalLayers.isEmpty else { return }
                do {
                    // A URL to the GetCapabilities endpoint of a WMS service
                    let wmsServiceURL = URL(string: "https://gis.ncdc.noaa.gov/arcgis/services/cdo/nexrad/MapServer/WMSServer?request=GetCapabilities&service=WMS")!
                    // the names of the layers to load at the WMS service
                    let wmsServiceLayerNames = ["1"]
                    // Initialize the WMS layer with the service URL and uniquely identifying WMS layer names
                    let wmsLayer = WMSLayer(url: wmsServiceURL, layerNames: wmsServiceLayerNames)
                    // Load the WMS layer
                    try await wmsLayer.load()
                    // Adds the WMS layer to the map's operational layer.
                    map.addOperationalLayer(wmsLayer)
                } catch {
                    // Presents an error message URL fails to load.
                    self.error = error
                }
            }
            .alert(isPresented: $isShowingAlert, presentingError: error)
    }
}
