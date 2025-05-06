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

struct ApplyRGBRendererView: View {
    /// An empty map.
    @State private var map = Map()
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    /// The raster layer to apply RGB renderer.
    @State private var rasterLayer: RasterLayer?
    
    /// A Boolean value indicating whether the settings view should be presented.
    @State private var isShowingSettings = false
    
    var body: some View {
        MapView(map: map)
            .errorAlert(presentingError: $error)
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button("Stretch Parameter Settings") {
                        isShowingSettings = true
                    }
                    .popover(isPresented: $isShowingSettings) {
                        NavigationStack {
                            SettingsView(rasterLayer: rasterLayer!)
                        }
                        .presentationDetents([.fraction(0.5)])
                        .frame(idealWidth: 320, idealHeight: 360)
                    }
                    .disabled(rasterLayer == nil)
                }
            }
            .task {
                do {
                    let raster = Raster(
                        fileURL: Bundle.main.url(
                            forResource: "Shasta",
                            withExtension: "tif",
                            subdirectory: "raster-file/raster-file"
                        )!
                    )
                    let rasterLayer = RasterLayer(raster: raster)
                    self.rasterLayer = rasterLayer
                    try await rasterLayer.load()
                    map = Map(basemap: Basemap(baseLayer: rasterLayer))
                    if let extent = rasterLayer.fullExtent {
                        map.initialViewpoint = Viewpoint(boundingGeometry: extent)
                    }
                } catch {
                    self.error = error
                }
            }
    }
}
