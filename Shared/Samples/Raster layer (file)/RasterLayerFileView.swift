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

struct RasterLayerFileView: View {
    /// A map with imagery basemap.
    @State private var map = Map(basemapStyle: .arcGISImageryStandard)
    
    /// The raster layer.
    @State private var rasterLayer: RasterLayer!
    
    /// The center of the full extent of the raster layer.
    @State private var center = Point(x: 0, y: 0)
    
    @State private var viewpoint: Viewpoint!
    
    /// A Boolean value indicating whether to show an alert.
    @State private var isShowingAlert = false
    
    /// The error shown in the alert.
    @State private var error: Error? {
        didSet { isShowingAlert = error != nil }
    }
    
    /// Loads a local mobile map package.
    private func loadRasterLayer() async throws {
        // Loads the local mobile map package.
        let shastaURL = Bundle.main.url(forResource: "Shasta", withExtension: "tif", subdirectory: "raster-file")!
        let raster = Raster(fileURL: shastaURL)
        rasterLayer = RasterLayer(raster: raster)
        map.addOperationalLayer(rasterLayer)
        try await rasterLayer.load()
        // Gets the first map in the mobile map package.
        center = rasterLayer.fullExtent!.center
    }
    
    var body: some View {
        // Creates a map view to display the map.
        MapView(map: map, viewpoint: Viewpoint(center: center, scale: 8_0000))
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
