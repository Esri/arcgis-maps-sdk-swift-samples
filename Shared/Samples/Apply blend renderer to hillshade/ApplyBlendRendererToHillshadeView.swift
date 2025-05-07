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

struct ApplyBlendRendererToHillshadeView: View {
    /// A map with no specified style.
    @State private var map = Map()
    
    /// The imagery basemap.
    private let imageryBasemap: Basemap = {
        let raster = Raster(fileURL: .shasta)
        let rasterLayer = RasterLayer(raster: raster)
        return Basemap(baseLayer: rasterLayer)
    }()
    
    /// The elevation basemap.
    private let elevationBasemap: Basemap = {
        let raster = Raster(fileURL: .shastaElevation)
        let rasterLayer = RasterLayer(raster: raster)
        return Basemap(baseLayer: rasterLayer)
    }()
    
    /// The imagery basemap raster layer.
    private var imageryBasemapLayer: RasterLayer {
        imageryBasemap.baseLayers[0] as! RasterLayer
    }
    
    /// The elevation basemap raster layer.
    private var elevationBasemapLayer: RasterLayer {
        elevationBasemap.baseLayers[0] as! RasterLayer
    }
    
    /// The elevation raster.
    private let elevationRaster = Raster(fileURL: .shastaElevation)
    
    /// A Boolean value indicating whether the settings view should be presented.
    @State private var isShowingSettings = false
    
    /// The settings for a blend renderer.
    struct RendererSettings: Equatable {
        /// The renderer altitude.
        var altitude = 0.0
        /// The renderer azimuth.
        var azimuth = 0.0
        /// The renderer slope type.
        var slopeType: HillshadeRenderer.SlopeType?
        /// The renderer color ramp preset.
        var colorRampPreset: ColorRamp.Preset?
        
        /// The renderer color ramp.
        var colorRamp: ColorRamp? {
            colorRampPreset.map { ColorRamp(preset: $0, size: 800) }
        }
        ///  A Boolean value indicating whether the renderer has a color ramp.
        var hasColorRamp: Bool {
            colorRamp != nil
        }
    }
    
    /// The renderer settings.
    @State private var rendererSettings = RendererSettings()
    
    var body: some View {
        MapView(map: map)
            .onChange(of: rendererSettings, initial: true) {
                let rasterLayer = rendererSettings.hasColorRamp ? elevationBasemapLayer : imageryBasemapLayer
                rasterLayer.renderer = BlendRenderer(
                    elevationRaster: elevationRaster,
                    outputMinValues: [9],
                    outputMaxValues: [255],
                    sourceMinValues: [],
                    sourceMaxValues: [],
                    noDataValues: [],
                    gammas: [],
                    colorRamp: rendererSettings.colorRamp,
                    altitude: rendererSettings.altitude,
                    azimuth: rendererSettings.azimuth,
                    slopeType: rendererSettings.slopeType
                )
                map.basemap = rendererSettings.hasColorRamp ? elevationBasemap : imageryBasemap
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button("Renderer Settings") {
                        isShowingSettings = true
                    }
                    .popover(isPresented: $isShowingSettings) {
                        SettingsView(settings: $rendererSettings)
                            .presentationDetents([.fraction(0.5)])
                            .frame(idealWidth: 320, idealHeight: 320)
                    }
                }
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
