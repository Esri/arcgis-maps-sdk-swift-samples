// Copyright 2022 Esri
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

struct AddRasterFromFileView: View {
    /// The model used to store the geo model and other expensive objects
    /// used in this view.
    private class Model: ObservableObject {
        /// A map with imagery basemap and a raster layer.
        let map = Map(basemapStyle: .arcGISImageryStandard)
    }
    
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// A Boolean value indicating whether to show an alert.
    @State private var isShowingAlert = false
    
    /// The error shown in the alert.
    @State private var error: Error? {
        didSet { isShowingAlert = error != nil }
    }
    
    /// The current viewpoint of the map view.
    @State private var viewpoint: Viewpoint?
    
    var body: some View {
        // Creates a map view with a viewpoint to display the map.
        MapView(map: model.map, viewpoint: viewpoint)
            .onViewpointChanged(kind: .centerAndScale) { viewpoint = $0 }
            .alert(isPresented: $isShowingAlert, presentingError: error)
            .task {
                do {
                    // Gets the Shasta.tif file URL.
                    let shastaURL = Bundle.main.url(forResource: "Shasta", withExtension: "tif", subdirectory: "raster-file/raster-file")!
                    // Creates a raster with the file URL.
                    let raster = Raster(fileURL: shastaURL)
                    // Creates a raster layer using the raster object.
                    let rasterLayer = RasterLayer(raster: raster)
                    try await rasterLayer.load()
                    // Adds the raster layer to the map's operational layer.
                    model.map.addOperationalLayer(rasterLayer)
                    viewpoint = Viewpoint(center: rasterLayer.fullExtent!.center, scale: 8e4)
                } catch {
                    // Presents an error message if the raster fails to load.
                    self.error = error
                }
            }
    }
}
