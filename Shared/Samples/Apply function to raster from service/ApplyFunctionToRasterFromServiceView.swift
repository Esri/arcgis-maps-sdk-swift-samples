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

struct ApplyFunctionToRasterFromServiceView: View {
    /// The map that will be shown.
    @State private var map = Map(basemapStyle: .arcGISStreets)
    
    var body: some View {
        MapViewReader { mapViewProxy in
            // Creates a map view to display the map.
            MapView(map: map)
                .task {
                    // Creates an image service raster.
                    let imageServiceRaster = ImageServiceRaster(
                        url: URL(string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/NLCDLandCover2001/ImageServer")!
                    )
                    // Creates a raster function from a json string.
                    let function = try! RasterFunction.fromJSON(rasterFunctionJSON) // swiftlint:disable:this force_try
                    // Sets the arguments on the function.
                    function.arguments!.setRaster(
                        imageServiceRaster,
                        forArgumentNamed: function.arguments!.rasterNames.first!
                    )
                    // Creates a raster layer from the raster function.
                    let rasterLayer = RasterLayer(raster: Raster(rasterFunction: function))
                    // Adds the raster layer to the map.
                    map.addOperationalLayer(rasterLayer)
                    // Loads the raster layer so that we can zoom to its extent.
                    try? await rasterLayer.load()
                    if let extent = rasterLayer.fullExtent {
                        await mapViewProxy.setViewpointGeometry(extent)
                    }
                }
        }
    }
    
    /// The raster function json string to apply to the image service raster.
    private var rasterFunctionJSON: String {
        #"""
        {
          "raster_function_arguments":
          {
            "z_factor":{"double":25.0,"type":"Raster_function_variable"},
            "slope_type":{"raster_slope_type":"none","type":"Raster_function_variable"},
            "azimuth":{"double":315,"type":"Raster_function_variable"},
            "altitude":{"double":45,"type":"Raster_function_variable"},
            "type":"Raster_function_arguments",
            "raster":{"name":"raster","is_raster":true,"type":"Raster_function_variable"},
            "nbits":{"int":8,"type":"Raster_function_variable"}
          },
          "raster_function":{"type":"Hillshade_function"},
          "type":"Raster_function_template"
        }
        """#
    }
}

#Preview {
    ApplyFunctionToRasterFromServiceView()
}
