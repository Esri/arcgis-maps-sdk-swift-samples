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
    
    /// The current draw status of the map.
    @State private var currentDrawStatus: DrawStatus = .inProgress
    
    /// A map with a dark gray basemap and a raster layer.
    @State private var map: Map = {
        let map = Map(basemapStyle: .arcGISDarkGrayBase)
        // Creates an initial viewpoint with a coordinate point centered on
        // San Francisco's Golden Gate Bridge.
        map.initialViewpoint = Viewpoint(
            center: Point(x: -13_637_000, y: 4_550_000, spatialReference: .webMercator),
            scale: 100_000
        )
        // Creates a raster from an image service.
        let imageServiceRaster = ImageServiceRaster(url: .imageServiceURL)
        // Creates a raster layer from the raster.
        let rasterLayer = RasterLayer(raster: imageServiceRaster)
        map.addOperationalLayer(rasterLayer)
        return map
    }()
    
    /// The raster layer in the map.
    private var rasterLayer: RasterLayer {
        map.operationalLayers.first as! RasterLayer
    }
    
    var body: some View {
        MapView(map: map)
            .onDrawStatusChanged { drawStatus in
                // Updates the state when the map's draw status changes.
                withAnimation {
                    currentDrawStatus = drawStatus
                }
            }
            .overlay(alignment: .center) {
                if currentDrawStatus == .inProgress {
                    ProgressView("Drawing…")
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                        .shadow(radius: 50)
                }
            }
            .task {
                do {
                    // Loads a raster layer from online service.
                    try await rasterLayer.load()
                } catch {
                    // Presents an error message if the raster fails to load.
                    self.error = error
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
