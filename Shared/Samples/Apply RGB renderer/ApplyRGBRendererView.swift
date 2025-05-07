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
    /// A map with a raster layer.
    @State private var map: Map = {
        let raster = Raster(
            fileURL: Bundle.main.url(
                forResource: "Shasta",
                withExtension: "tif",
                subdirectory: "raster-file/raster-file"
            )!
        )
        return Map(basemap: Basemap(baseLayer: RasterLayer(raster: raster)))
    }()
    
    /// The stretch type to apply to the raster layer.
    @State private var stretchType: StretchType = .histogramEqualization
    
    /// The raster layer to apply RGB renderer.
    private var rasterLayer: RasterLayer {
        map.basemap?.baseLayers[0] as! RasterLayer
    }
    
    /// A Boolean value indicating whether the settings view should be presented.
    @State private var isShowingSettings = false
    
    var body: some View {
        MapView(map: map)
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button("Stretch Parameter Settings") {
                        isShowingSettings = true
                    }
                    .popover(isPresented: $isShowingSettings) {
                        NavigationStack {
                            SettingsView(rasterLayer: rasterLayer, stretchType: $stretchType)
                        }
                        .presentationDetents([.fraction(0.5)])
                        .frame(idealWidth: 320, idealHeight: 360)
                    }
                }
            }
    }
}
