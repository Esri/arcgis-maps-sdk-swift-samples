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
    /// A map with a standard imagery basemap style.
    @StateObject private var map = Map(basemapStyle: .arcGISImageryStandard)
    
    /// The center of the full extent of the raster layer.
    @State private var center = Point(x: 0, y: 0)
    
    /// A Boolean value indicating whether to show an alert.
    @State private var isShowingAlert = false
    
    /// The error shown in the alert.
    @State private var error: Error? {
        didSet { isShowingAlert = error != nil }
    }
    
    /// Loads a local raster layer.
    private func loadRasterLayer() async throws {
        // Gets the Shasta.tif file URL.
        let shastaURL = Bundle.main.url(forResource: "Shasta", withExtension: "tif")!
        // Creates a raster with the file URL.
        let raster = Raster(fileURL: shastaURL)
        // Creates a raster layer using the raster object.
        let rasterLayer = RasterLayer(raster: raster)
        // Adds the raster layer to the map's operational layer.
        map.addOperationalLayer(rasterLayer)
        // Loads the raster layer.
        try await rasterLayer.load()
        // Gets the center point of the raster layer's full extent.
        center = rasterLayer.fullExtent!.center
    }
    
    var body: some View {
        // Creates a map view with a viewpoint to display the map.
        MapView(map: map, viewpoint: Viewpoint(center: center, scale: 80_000))
            .task {
                do {
                    try await loadRasterLayer()
                } catch {
                    // Presents an error message if the map fails to load.
                    self.error = error
                }
            }
            .alert(isPresented: $isShowingAlert, presentingError: error)
    }
}
