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

struct RenderMultilayerSymbolsView: View {
    /// A map with a light gray basemap.
    @State private var map = Map(basemapStyle: .arcGISLightGray)
    
    /// The graphics overlay containing the multilayer graphics and associated text graphics.
    @State private var graphicsOverlay = GraphicsOverlay()
    
    init() {
        // Add graphics to graphics overlay.
        var graphics: [Graphic] = []
        graphics.append(contentsOf: makeMultilayerPointPictureMarkerGraphics())
        graphicsOverlay.addGraphics(graphics)
    }
    
    var body: some View {
        MapView(map: map, graphicsOverlays: [graphicsOverlay])
    }
}

private extension RenderMultilayerSymbolsView {
    // MARK: Methods
    
    /// Creates a text symbol used as a graphic label on the map.
    /// - Parameter text: The `String` used to create the `TextSymbol`.
    /// - Returns: A new `TextSymbol` object.
    private func makeTextSymbol(text: String) -> TextSymbol {
        let textSymbol = TextSymbol(text: text, color: .black, size: 20)
        textSymbol.backgroundColor = .white
        return textSymbol
    }
    
    // MARK: MultilayerPoint Picture Markers
    
    /// Creates the multilayer point picture marker graphics.
    /// - Returns: An `Array` of `Graphic`s.
    private func makeMultilayerPointPictureMarkerGraphics() -> [Graphic] {
        var graphics: [Graphic] = []
        
        // Create a text graphic for the label.
        graphics.append(Graphic(
            geometry: Point(x: -80, y: 50, spatialReference: .wgs84),
            symbol: makeTextSymbol(text: "MultilayerPoint\nPicture Markers")
        ))
        
        // Create a campsite graphic using a URL.
        let campsiteLayer = PictureMarkerSymbolLayer(url: .campsiteImage)
        graphics.append(
            makePictureMarkerSymbolLayerGraphic(symbolLayer: campsiteLayer, offset: 0)
        )
        
        // Create a pin graphic using an image.
        if let pinImage = UIImage(named: "PinBlueStar") {
            let pinLayer = PictureMarkerSymbolLayer(image: pinImage)
            graphics.append(
                makePictureMarkerSymbolLayerGraphic(symbolLayer: pinLayer, offset: 40)
            )
        }
        return graphics
    }
    
    /// Creates a graphic from a picture marker symbol layer.
    /// - Parameters:
    ///   - symbolLayer: The `PictureMarkerSymbolLayer` used to create the `MultilayerPointSymbol`.
    ///   - offset: The `Double` used to keep a consistent distance between symbols in the same column
    /// - Returns: A new `Graphic` object.
    private func makePictureMarkerSymbolLayerGraphic(symbolLayer: PictureMarkerSymbolLayer, offset: Double) -> Graphic {
        // Create a multilayer point symbol using the picture marker symbol layer.
        symbolLayer.size = 40
        let symbol = MultilayerPointSymbol(symbolLayers: [symbolLayer])
        
        // Create the location for symbol.
        let symbolPoint = Point(x: -80, y: 20 - offset, spatialReference: .wgs84)
        
        // Create the graphic for symbol.
        return Graphic(geometry: symbolPoint, symbol: symbol)
    }
}

private extension URL {
    /// The URL to a campsite image on ArcGIS online.
    static let campsiteImage = URL(
        string: "https://static.arcgis.com/images/Symbols/OutdoorRecreation/Camping.png"
    )!
}
