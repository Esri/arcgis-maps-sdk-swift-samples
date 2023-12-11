// Copyright 2023 Esri
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

struct StylePointWithPictureMarkerSymbolsView: View {
    /// A graphics overlay to hold the picture marker symbol graphics.
    @State private var graphicsOverlay: GraphicsOverlay = {
        let graphics = [
            makePictureMarkerSymbolFromImage(),
            makePictureMarkerSymbolFromURL()
        ]
        return GraphicsOverlay(graphics: graphics)
    }()
    
    /// A map with topographic basemap and centered on Harman's Cross in England.
    @State private var map: Map = {
        let map = Map(basemapStyle: .arcGISTopographic)
        map.initialViewpoint = Viewpoint(
            center: Point(x: -225166.5, y: 6551249, spatialReference: .webMercator),
            scale: 1e5
        )
        return map
    }()
    
    /// Creates a picture marker symbol from an image in the project assets.
    /// - Returns: A picture marker symbol
    private static func makePictureMarkerSymbolFromImage() -> Graphic {
        let imageName = "PinBlueStar"
        
        // Create pin symbol using the image.
        let pinSymbol = PictureMarkerSymbol(image: UIImage(named: imageName)!)
        
        // Change offsets, so the symbol aligns properly to the point.
        pinSymbol.offsetY = pinSymbol.image!.size.height / 2
        
        // Create the location for pin.
        let pinPoint = Point(x: -226773, y: 6550477, spatialReference: .webMercator)
        
        // Create the graphic for pin.
        let pinGraphic = Graphic(geometry: pinPoint, symbol: pinSymbol)
        
        return pinGraphic
    }
    
    /// Creates a picture marker symbol using a remote image.
    /// - Returns: A picture marker symbol
    private static func makePictureMarkerSymbolFromURL() -> Graphic {
        let imageURL = URL(
            string: "https://static.arcgis.com/images/Symbols/OutdoorRecreation/Camping.png"
        )!
        
        // Create pin symbol using the URL.
        let campsiteSymbol = PictureMarkerSymbol(url: imageURL)
        
        // FYI, for picture marker symbols created with the
        // `PictureMarkerSymbol(url: URL)` initializer, the `image` property
        // will be `nil` until the symbol is loaded using the
        // `func load() async throws` method. We are not accessing that
        // property here, so we don't need to explicitly load it. The symbol
        // will be loaded automatically prior to drawing.
        
        // Optionally set the size.
        // (If not set, the size in pixels of the image will be used.)
        campsiteSymbol.width = 24
        campsiteSymbol.height = 24
        
        // Create the location for campsite.
        let campsitePoint = Point(x: -223560, y: 6552021, spatialReference: .webMercator)
        
        // Create the graphic for campsite.
        let campsiteGraphic = Graphic(geometry: campsitePoint, symbol: campsiteSymbol)
        
        return campsiteGraphic
    }
    
    var body: some View {
        // Create a map view to display the map and point graphics.
        MapView(map: map, graphicsOverlays: [graphicsOverlay])
    }
}

#Preview {
    StylePointWithPictureMarkerSymbolsView()
}
