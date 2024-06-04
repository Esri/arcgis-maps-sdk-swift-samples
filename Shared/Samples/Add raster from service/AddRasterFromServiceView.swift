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

struct AddRasterFromServiceView: View {
    /// The error shown in the error alert.
    @State private var error: Error?
    
    /// The current viewpoint of the map view.
    @State private var viewpoint: Viewpoint?
    
    /// A Boolean value indicating whether a download operation is in progress.
    @State private var isLoading = false
    
    /// A map with a dark gray basemap and a raster layer.
    @State private var map: Map = {
        let map = Map(basemapStyle: .arcGISDarkGrayBase)
        // Creates an initial Viewpoint with a coordinate point centered on San Franscisco's Golden Gate Bridge.
        map.initialViewpoint = Viewpoint(
            center: Point(x: -13637000, y: 4550000, spatialReference: .webMercator),
            scale: 100_000
        )
        let imageServiceRaster = ImageServiceRaster(url: .imageServiceURL)
        let rasterLayer = RasterLayer(raster: imageServiceRaster)
        map.addOperationalLayer(rasterLayer)
        return map
    }()
    
    var body: some View {
        MapViewReader { mapViewProxy in
            MapView(map: map, viewpoint: viewpoint)
                .onViewpointChanged(kind: .centerAndScale) { viewpoint = $0 }
                .overlay(alignment: .center) {
                    if isLoading {
                        ProgressView("Loading...")
                            .padding()
                            .background(.ultraThickMaterial)
                            .cornerRadius(10)
                            .shadow(radius: 50)
                    }
                }
                .task {
                    guard let rasterLayer = map.operationalLayers.first as? RasterLayer else {
                        return
                    }
                    do {
                        isLoading = true
                        defer { isLoading = false }
                        // Downloads raster from online service.
                        try await rasterLayer.load()
                    } catch {
                        // Presents an error message if the raster fails to load.
                        self.error = error
                    }
                }
        }
        .errorAlert(presentingError: $error)
    }
}

private extension URL {
    static let imageServiceURL = URL(string: "https://gis.ngdc.noaa.gov/arcgis/rest/services/bag_bathymetry/ImageServer")!
}

#Preview {
    AddRasterFromServiceView()
}
