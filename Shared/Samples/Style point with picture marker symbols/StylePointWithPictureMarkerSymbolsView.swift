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
    /// The graphics overlay to hold the point graphics.
    @State private var graphicsOverlay = GraphicsOverlay()
    
    /// A map with topographic basemap and centered on Harman's Cross in England.
    @State private var map: Map = {
        let map = Map(basemapStyle: .arcGISTopographic)
        map.initialViewpoint = Viewpoint(
            center: Point(x: -225166.5, y: 6551249, spatialReference: .webMercator),
            scale: 1e5
        )
        return map
    }()
    
    /// Adds a picture maker from an image in the project assets.
    private func addPictureMarkerSymbolFromImage() {
        let imageName = "PinBlueStar"
        
        // Create pin symbol using the image.
        let pinSymbol = PictureMarkerSymbol(image: UIImage(named: imageName)!)
        
        // Change offsets, so the symbol aligns properly to the point.
        pinSymbol.offsetY = pinSymbol.image!.size.height / 2
        
        // Create the location for pin.
        let pinPoint = Point(x: -226773, y: 6550477, spatialReference: .webMercator)
        
        // Create the graphic for pin.
        let pinGraphic = Graphic(geometry: pinPoint, symbol: pinSymbol)
        
        // Add the graphic to the overlay.
        self.graphicsOverlay.addGraphic(pinGraphic)
    }
    
    /// Adds a picture marker using a remote image.
    private func addPictureMarkerSymbolFromURL() {
        let imageURL = URL(string: "https://static.arcgis.com/images/Symbols/OutdoorRecreation/Camping.png")!
            
        // Create pin symbol using the URL.
        let campsiteSymbol = PictureMarkerSymbol(url: imageURL)
            
        // Optionally set the size.
        // (If not set, the size in pixels of the image will be used.)
        campsiteSymbol.width = 24
        campsiteSymbol.height = 24
            
        // Create the location for campsite.
        let campsitePoint = Point(x: -223560, y: 6552021, spatialReference: .webMercator)
            
        // Create the graphic for campsite.
        let campsiteGraphic = Graphic(geometry: campsitePoint, symbol: campsiteSymbol)
            
        // Add the graphic to the overlay.
        self.graphicsOverlay.addGraphic(campsiteGraphic)
    }
    
    init() {
        // Add picture marker symbol using a remote image.
        self.addPictureMarkerSymbolFromURL()
        
        // Add picture marker symbol using image in assets.
        self.addPictureMarkerSymbolFromImage()
    }

    var body: some View {
        // Creates a map view to display the map and point graphics.
        MapView(map: map, graphicsOverlays: [graphicsOverlay])
    }
}
