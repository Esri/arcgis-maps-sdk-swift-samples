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

struct ApplyColormapRendererToRasterView: View {
    /// Creates the raster layer used by this sample.
    static func makeRasterLayer() -> RasterLayer {
        // Creates a raster and raster layer.
        let raster = Raster(name: "ShastaBW", extension: "tif", bundle: nil)!
        let rasterLayer = RasterLayer(raster: raster)
        
        // Creates a colormap renderer and assigns it to the raster layer.
        let colors = Array(repeating: UIColor.red, count: 150)
                   + Array(repeating: UIColor.yellow, count: 151)
        rasterLayer.renderer = ColormapRenderer(colors: colors)
        
        return rasterLayer
    }
    
    /// Creates the map for this sample.
    static func makeMap() -> Map {
        let map = Map(basemapStyle: .arcGISImageryStandard)
        map.addOperationalLayer(makeRasterLayer())
        return map
    }
    
    /// The map displayed by the map view.
    @State private var map = makeMap()
    /// The error if the raster layer load operation failed, otherwise `nil`.
    @State private var rasterLayerLoadError: Error?
    
    /// The raster layer from the map.
    var rasterLayer: RasterLayer { map.operationalLayers.first as! RasterLayer }
    
    var body: some View {
        MapViewReader { mapView in
            MapView(map: map)
                .task {
                    // Loads the raster layer to get the full extent.
                    do {
                        try await rasterLayer.load()
                        if let center = rasterLayer.fullExtent?.center {
                            let viewpoint = Viewpoint(center: center, scale: 80_000)
                            await mapView.setViewpoint(viewpoint)
                        }
                    } catch {
                        rasterLayerLoadError = error
                    }
                }
                .errorAlert(presentingError: $rasterLayerLoadError)
        }
    }
}
