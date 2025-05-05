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
//    /// The model used to store the geo model and other expensive objects
//    /// used in this view.
//    private class Model: ObservableObject {
//        /// A map with imagery basemap.
//        let map = Map(basemapStyle: .arcGISImagery)
//    }
//    
//    /// The view model for the sample.
//    @StateObject private var model = Model()
//    
//    var body: some View {
//        // Creates a map view to display the map.
//        MapView(map: model.map)
//    }
    
    /// A map with imagery basemap and a raster layer.
    @State private var map = Map(basemapStyle: .arcGISImageryStandard)
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    /// The current viewpoint of the map view.
    @State private var viewpoint: Viewpoint?
    
    var body: some View {
        // Creates a map view with a viewpoint to display the map.
        MapView(map: map, viewpoint: viewpoint)
            .onViewpointChanged(kind: .centerAndScale) { viewpoint = $0 }
            .errorAlert(presentingError: $error)
            .task {
                guard map.operationalLayers.isEmpty else { return }
                // Gets the raster file URL.
                let rasterFileURL = Bundle.main.url(forResource: "SA_EVI_8Day_03May20", withExtension: "tif", subdirectory: "SA_EVI_8Day_03May20")!
                // Creates a raster with the file URL.
                let raster = Raster(fileURL: rasterFileURL)
                // Creates a raster layer using the raster object.
                let rasterLayer = RasterLayer(raster: raster)
                
                // Apply the hillshade renderer to the raster layer
                rasterLayer.renderer = HillshadeRenderer(
                    altitude: 45,
                    azimuth: 315,
                    slopeType: nil,
                    zFactor: 0.000016,
                    pixelSizeFactor: 1,
                    pixelSizePower: 1,
                    outputBitDepth: 8
                )
                
                do {
                    try await rasterLayer.load()
                    // Adds the raster layer to the map's operational layer.
                    map.addOperationalLayer(rasterLayer)
                    viewpoint = Viewpoint(boundingGeometry: rasterLayer.fullExtent!)
                } catch {
                    // Presents an error message if the raster fails to load.
                    self.error = error
                }
            }
    }
}

#Preview {
    ApplyHillshadeRendererToRasterView()
}
