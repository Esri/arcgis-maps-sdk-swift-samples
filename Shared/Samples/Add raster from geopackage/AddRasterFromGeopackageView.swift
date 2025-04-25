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

struct AddRasterFromGeopackageView: View {
    /// A map with lgiht gray basemap and a raster layer.
    @State private var map = Map(basemapStyle: .arcGISLightGray)
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    /// The current viewpoint of the map view.
    @State private var viewpoint: Viewpoint?
    
    var body: some View {
        MapView(map: map, viewpoint: viewpoint)
            .onViewpointChanged(kind: .centerAndScale) { viewpoint = $0 }
            .errorAlert(presentingError: $error)
            .task {
                do {
                    guard let geopackage = GeoPackage(name: "AuroraCO", bundle: .main) else {
                        return
                    }
                    try await geopackage.load()
                    let rasterLayers = geopackage.rasters.map(RasterLayer.init(raster:))
                    for layer in rasterLayers {
                        // Makes the layer semi-transparent so it doesn't
                        // obscure the contents beneath it.
                        layer.opacity = 0.5
                    }
                    viewpoint = Viewpoint(latitude: 39.7294, longitude: -104.8319, scale: 3e5)
                    map.addOperationalLayers(rasterLayers)
                } catch {
                    // Updates the error and shows an alert if any failure occurs.
                    self.error = error
                }
            }
    }
}

#Preview {
    AddRasterFromGeopackageView()
}
