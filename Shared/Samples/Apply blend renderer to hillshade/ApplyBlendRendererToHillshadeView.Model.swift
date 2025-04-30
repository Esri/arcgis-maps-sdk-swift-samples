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

extension ApplyBlendRendererToHillshadeView {
    /// The view model for the sample.
    class Model: ObservableObject {
        /// A map with a Shasta raster layer.
        @Published var map: Map = {
            let raster = Raster(fileURL: .shasta)
            let rasterLayer = RasterLayer(raster: raster)
            return Map(basemap: Basemap(baseLayer: rasterLayer))
        }()
        
        /// The raster layer.
        private var rasterLayer: RasterLayer {
            map.basemap?.baseLayers[0] as! RasterLayer
        }
        
        /// The elevation raster.
        private let elevationRaster: Raster = {
            Raster(fileURL: .shastaElevation)
        }()
        
        /// The blend renderer altitude.
        @Published var altitude = 0.0
        
        /// The blend renderer azimuth.
        @Published var azimuth = 0.0
        
        /// The blend renderer slope type.
        @Published var slopeType: HillshadeRenderer.SlopeType?
        
        /// The blend renderer color ramp preset.
        @Published var colorRampPreset: ColorRamp.Preset?
        
        /// The color ramp for the blend renderer.
        private var colorRamp: ColorRamp? {
            if let colorRampPreset {
                ColorRamp(preset: colorRampPreset, size: 800)
            } else {
                .none
            }
        }
        
        /// Applies the settings to the blend renderer on the raster layer.
        func applyRendererSettings() {
            let blendRenderer = BlendRenderer(
                elevationRaster: elevationRaster,
                outputMinValues: [],
                outputMaxValues: [],
                sourceMinValues: [],
                sourceMaxValues: [],
                noDataValues: [],
                gammas: [],
                colorRamp: colorRamp,
                altitude: altitude,
                azimuth: azimuth,
                slopeType: slopeType
            )
            
            // Apply blend renderer to raster layer.
            rasterLayer.renderer = blendRenderer
        }
    }
}

private extension URL {
    /// The URL to the Shasta data.
    static var shasta: URL {
        Bundle.main.url(forResource: "Shasta", withExtension: "tif", subdirectory: "raster-file/raster-file")!
    }
    
    /// The URL to the Shasta elevation data.
    static var shastaElevation: URL {
        Bundle.main.url(forResource: "Shasta_Elevation", withExtension: "tif", subdirectory: "Shasta_Elevation")!
    }
}
