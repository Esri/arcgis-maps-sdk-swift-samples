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
        /// The raster renderer.
        var renderer: HillshadeRenderer
        
        init() {
            // Gets the raster file URL.
            let rasterFileURL = Bundle.main.url(forResource: "srtm", withExtension: "tiff", subdirectory: "srtm")!
            
            // Creates a raster with the file URL.
            let raster = Raster(fileURL: rasterFileURL)
            
            // Creates a raster layer using the raster object.
            let rasterLayer = RasterLayer(raster: raster)
            
            // Apply the hillshade renderer to the raster layer.
            renderer = HillshadeRenderer(
                altitude: 45,
                azimuth: 315,
                slopeType: nil,
                zFactor: 0.000016,
                pixelSizeFactor: 1,
                pixelSizePower: 1,
                outputBitDepth: 8
            )
            rasterLayer.renderer = renderer
            
            // Create our map.
            map = Map(basemap: .init(baseLayer: rasterLayer))
        }
    }
    
    /// The view model for the sample.
    @State private var map = Self.makeMap()
    
    @State private var isSettingsPanelPresented: Bool = false
    
    var rasterLayer: RasterLayer {
        map.basemap!.baseLayers[0] as! RasterLayer
    }
    
    @State private var renderer: HillshadeRenderer = .init(altitude: 0, azimuth: 0, slopeType: nil)
    
    var body: some View {
        // Creates a map view to display the map.
        MapView(map: map)
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        isSettingsPanelPresented = true
                    } label: {
                        Text("Settings")
                    }
                    .popover(isPresented: $isSettingsPanelPresented, arrowEdge: .bottom) {
                        ApplyHillshadeRendererToRasterView.SettingsView(
                            renderer: $renderer
                        )
                    }
                }
            }
            .onChange(of: ObjectIdentifier(renderer)) {
                rasterLayer.renderer = renderer
            }
    }
    
    private static func makeMap() -> Map {
        // Gets the raster file URL.
        let rasterFileURL = Bundle.main.url(forResource: "srtm", withExtension: "tiff", subdirectory: "srtm")!
        
        // Creates a raster with the file URL.
        let raster = Raster(fileURL: rasterFileURL)
        
        // Creates a raster layer using the raster object.
        let rasterLayer = RasterLayer(raster: raster)
        
        // Apply the hillshade renderer to the raster layer.
        let renderer = HillshadeRenderer(
            altitude: 45,
            azimuth: 315,
            slopeType: nil,
            zFactor: 0.000016,
            pixelSizeFactor: 1,
            pixelSizePower: 1,
            outputBitDepth: 8
        )
        rasterLayer.renderer = renderer
        
        // Create our map.
        return Map(basemap: .init(baseLayer: rasterLayer))
    }
}

#Preview {
    ApplyHillshadeRendererToRasterView()
}
