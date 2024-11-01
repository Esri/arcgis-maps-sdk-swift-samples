// Copyright 2024 Esri
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

struct ApplyRasterRenderingRuleView: View {
    /// A map with a streets basemap.
    @State private var map = Map(basemapStyle: .arcGISStreets)
    
    /// An array of raster layers, each with a different rendering rule.
    @State private var rasterLayers: [RasterLayer] = []
    
    /// The name of rendering rule selected by the picker.
    @State private var selectedRenderingRule = "None"
    
    /// The viewpoint for zooming the map view to a layer's extent.
    @State private var viewpoint: Viewpoint?
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    var body: some View {
        MapView(map: map, viewpoint: viewpoint)
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Picker("Rendering Rule", selection: $selectedRenderingRule) {
                        ForEach(rasterLayers, id: \.name) { rasterLayer in
                            Text(rasterLayer.name)
                        }
                    }
                    .onChange(of: selectedRenderingRule) { newRule in
                        if let rasterLayer = rasterLayers.first(where: { $0.name == newRule }) {
                            setLayer(rasterLayer)
                        }
                    }
                }
            }
            .task {
                // Sets up the raster layers when the sample opens.
                do {
                    rasterLayers = try await makeRasterLayers()
                    await rasterLayers.load()
                    
                    if let rasterLayer = rasterLayers.first {
                        setLayer(rasterLayer)
                    }
                } catch {
                    self.error = error
                }
            }
            .errorAlert(presentingError: $error)
    }
    
    /// Sets a given layer on the map and zooms the viewpoint the layer's extent.
    /// - Parameter layer: The layer to set.
    private func setLayer(_ layer: Layer) {
        map.removeAllOperationalLayers()
        map.addOperationalLayer(layer)
        
        if let layerExtent = layer.fullExtent {
            viewpoint = Viewpoint(boundingGeometry: layerExtent)
        }
    }
    
    /// Creates raster layers for all the rendering rules from an image service raster.
    /// - Returns: An array of new `RasterLayer` objects.
    private func makeRasterLayers() async throws -> [RasterLayer] {
        // Creates and loads an image service raster using an image service URL.
        let imageServiceRaster = ImageServiceRaster(url: .charlotteLASImageService)
        try await imageServiceRaster.load()
        
        // Gets the rendering rule infos from the raster's service info.
        guard let renderingRuleInfos = imageServiceRaster.serviceInfo?.renderingRuleInfos else {
            return []
        }
        
        return renderingRuleInfos.map { renderingRuleInfo in
            // Creates another image service raster and sets its rendering rule using the info.
            // This is required since the raster can't be loaded when setting its rendering rule.
            let imageServiceRaster = ImageServiceRaster(url: .charlotteLASImageService)
            imageServiceRaster.renderingRule = RenderingRule(info: renderingRuleInfo)
            
            // Creates a layer using the raster.
            let rasterLayer = RasterLayer(raster: imageServiceRaster)
            rasterLayer.name = renderingRuleInfo.name
            
            return rasterLayer
        }
    }
}

private extension URL {
    /// The web URL to the "CharlotteLAS" image service containing LAS files for Charlotte, NC downtown area.
    static var charlotteLASImageService: URL {
        URL(string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/CharlotteLAS/ImageServer")!
    }
}

#Preview {
    ApplyRasterRenderingRuleView()
}
