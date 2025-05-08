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

struct ApplyFunctionToRasterFromFileView: View {
    /// A map with an imagery basemap style and raster layers.
    @State private var map: Map = {
        let map = Map(basemapStyle: .arcGISImageryStandard)
        map.initialViewpoint = Viewpoint(
            boundingGeometry: Envelope(
                xRange: -13606233.44023646 ... -13591503.517810356,
                yRange: 4971762.696708013...4982810.138527592,
                spatialReference: SpatialReference(wkid: .init(102100)!)
            )
        )
        // Creates a raster with the file URL.
        let elevationRaster = Raster(fileURL: .shastaElevation)
        
        // Creates a raster layer from the elevation raster.
        let rasterLayer = RasterLayer(raster: elevationRaster)
        rasterLayer.opacity = 0.5
        
        // Creates a raster function.
        let rasterFunction = RasterFunction(fileURL: .colorRasterFunction)
        
        // Sets the number of rasters required which is 2 in this case.
        rasterFunction.arguments?.setRaster(elevationRaster, forArgumentNamed: "raster")
        rasterFunction.arguments?.setRaster(elevationRaster, forArgumentNamed: "raster")
        
        // Creates a raster from the raster function.
        let colorRaster = Raster(rasterFunction: rasterFunction)
        
        // Creates a raster layer from the raster.
        let colorRasterLayer = RasterLayer(raster: colorRaster)
        colorRasterLayer.opacity = 0.5
        
        map.addOperationalLayers([rasterLayer, colorRasterLayer])
        return map
    }()
    
    var body: some View {
        MapView(map: map)
    }
}

private extension URL {
    /// The URL to the Shasta elevation data.
    static var shastaElevation: URL {
        Bundle.main.url(forResource: "Shasta_Elevation", withExtension: "tif", subdirectory: "Shasta_Elevation")!
    }
    
    /// The URL to the color raster function JSON.
    static var colorRasterFunction: URL {
        Bundle.main.url(forResource: "color", withExtension: "json")!
    }
}

#Preview {
    ApplyFunctionToRasterFromFileView()
}
