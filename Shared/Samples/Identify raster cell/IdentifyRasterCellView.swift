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

struct IdentifyRasterCellView: View {
    /// A map with an oceans basemap centered on Cape Town, South Africa.
    @State private var map: Map = {
        let map = Map(basemapStyle: .arcGISOceans)
        map.initialViewpoint = Viewpoint(latitude: -34.1, longitude: 18.6, scale: 1_155_500)
        return map
    }()
    
    /// A Boolean that indicates whether to show an error alert.
    @State private var isShowingErrorAlert = false
    
    /// The error shown in the error alert.
    @State private var error: Error? {
        didSet { isShowingErrorAlert = error != nil }
    }
    
    var body: some View {
        MapViewReader { proxy in
            MapView(map: map)
                .task {
                    do {
                        // Create a raster with the local file URL.
                        let raster = Raster(fileURL: .ndviRaster)
                        
                        // Create a raster layer using the raster.
                        let rasterLayer = RasterLayer(raster: raster)
                        try await rasterLayer.load()
                        
                        // Add the raster layer to the map as an operational layer.
                        map.addOperationalLayer(rasterLayer)
                    } catch {
                        self.error = error
                    }
                }
                .alert(isPresented: $isShowingErrorAlert, presentingError: error)
        }
    }
}

private extension URL {
    /// A URL to the local NDVI classification raster file.
    static var ndviRaster: Self {
        Bundle.main.url(forResource: "SA_EVI_8Day_03May20", withExtension: "tif", subdirectory: "SA_EVI_8Day_03May20")!
    }
}
