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

struct ApplyHillshadeRendererToRasterView: View {
    /// The model used to store the geo model and other expensive objects
    /// used in this view.
    class Model: ObservableObject {
        /// The map that will be shown.
        let map: Map
        /// The raster layer that will be added to the map.
        let rasterLayer: RasterLayer
        
        init() {
            // Create our map.
            map = Map(basemapStyle: .arcGISImageryStandard)
            
            // Gets the raster file URL.
            let rasterFileURL = Bundle.main.url(forResource: "SA_EVI_8Day_03May20", withExtension: "tif", subdirectory: "SA_EVI_8Day_03May20")!
            
            // Creates a raster with the file URL.
            let raster = Raster(fileURL: rasterFileURL)
            
            // Creates a raster layer using the raster object.
            rasterLayer = RasterLayer(raster: raster)
            
            // Apply the hillshade renderer to the raster layer.
            rasterLayer.renderer = HillshadeRenderer(
                altitude: 45,
                azimuth: 315,
                slopeType: nil,
                zFactor: 0.000016,
                pixelSizeFactor: 1,
                pixelSizePower: 1,
                outputBitDepth: 8
            )
            
            // Add the raster layer to the map.
            map.addOperationalLayer(rasterLayer)
        }
    }
    
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    var body: some View {
        MapViewReader { mapViewProxy in
            // Creates a map view to display the map.
            MapView(map: model.map)
                .task {
                    // When the view appears, load the raster layer so that
                    // we can zoom to its extent.
                    try? await model.rasterLayer.load()
                    if let extent = model.rasterLayer.fullExtent {
                        await mapViewProxy.setViewpointGeometry(extent)
                    }
                }
        }
    }
}

#Preview {
    ApplyHillshadeRendererToRasterView()
}
