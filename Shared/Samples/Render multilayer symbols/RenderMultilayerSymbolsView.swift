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
    
    /// The offset used to keep a consistent distance between symbols in the same column.
    private let offset = 20.0
    
    init() {
        // Add graphics to graphics overlay.
        var graphics: [Graphic] = []
        graphics.append(contentsOf: makeMultilayerPointPictureMarkerGraphics())
        graphics.append(contentsOf: makeMultilayerPolylineGraphics())
        graphics.append(contentsOf: makeMultilayerPolygonGraphics())
        graphics.append(contentsOf: makeMoreMultilayerSymbolGraphics())
        graphics.append(contentsOf: makeMultilayerPointSimpleMarkerGraphics())
        graphicsOverlay.addGraphics(graphics)
    }
    
    var body: some View {
        MapView(map: map, graphicsOverlays: [graphicsOverlay])
    }
}

private extension RenderMultilayerSymbolsView {
    /// Creates a text symbol with the text to be displayed on the map.
    /// - Parameter text: The `String` used to create the `TextSymbol`.
    /// - Returns: A new `TextSymbol` object.
    private func makeTextSymbol(text: String) -> TextSymbol {
        let textSymbol = TextSymbol(text: text, color: .black, size: 20)
        textSymbol.backgroundColor = .white
        return textSymbol
    }
    
    // MARK: - MultilayerPoint Picture Markers
    // TODO: add plus sign
    
    /// Creates the multilayer point picture marker graphics.
    /// - Returns: An `Array` of `Graphic`s.
    private func makeMultilayerPointPictureMarkerGraphics() -> [Graphic] {
        // Create a text graphic.
        var graphics = [Graphic(
                geometry: Point(x: -80, y: 50, spatialReference: .wgs84),
                symbol: makeTextSymbol(text: "MultilayerPoint\nPicture Markers")
            )]
        
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
    
    /// Creates a graphic using a multilayer point symbol.
    /// - Parameters:
    ///   - symbolLayer: The `PictureMarkerSymbolLayer` used to create the `MultilayerPointSymbol`.
    ///   - offset: The `Double` used to keep a consistent distance between symbols in the same column.
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
    
    // MARK: - Multilayer Polylines
    
    /// Creates the multilayer polyline graphics.
    /// - Returns: An `Array` of `Graphic`s.
    private func makeMultilayerPolylineGraphics() -> [Graphic] {
        // Create a text graphic.
        var graphics = [Graphic(
                geometry: Point(x: 0, y: 50, spatialReference: .wgs84),
                symbol: makeTextSymbol(text: "Multilayer\nPolylines")
            )]
        
        // Create the line graphics.
        graphics.append(contentsOf: [
            makeMultilayerPolylineSymbolGraphic(dashSpacing: [4.0, 6.0, 0.5, 6.0, 0.5, 6.0], offset: 0),
            makeMultilayerPolylineSymbolGraphic(dashSpacing: [4.0, 6.0], offset: offset),
            makeMultilayerPolylineSymbolGraphic(dashSpacing: [7.0, 9.0, 0.5, 9.0], offset: 2 * offset)
        ])
        
        return graphics
    }
    
    /// Creates a graphic using a multilayer polyline symbol.
    /// - Parameters:
    ///   - dashSpacing: The pattern of dots and dashes used to create a `DashGeometricEffect`.
    ///   - offset: The `Double` used to keep a consistent distance between symbols in the same column.
    /// - Returns: A new `Graphic` object.
    private func makeMultilayerPolylineSymbolGraphic(dashSpacing: [Double], offset: Double) -> Graphic {
        // Create a dash effect from the provided dash spacing.
        let dashEffect = DashGeometricEffect(dashTemplate: dashSpacing)
        
        // Create a stroke layer for the line symbols.
        let strokeLayer = SolidStrokeSymbolLayer(width: 3, color: .red, geometricEffects: [dashEffect])
        strokeLayer.capStyle = .round
        
        // Create a polyline for the multilayer polyline symbol.
        let polylineBuilder = PolylineBuilder(spatialReference: .wgs84)
        polylineBuilder.add(Point(x: -30, y: 20 - offset))
        polylineBuilder.add(Point(x: 30, y: 20 - offset))
        
        // Create a multilayer polyline symbol from the stroke layer.
        let lineSymbol = MultilayerPolylineSymbol(symbolLayers: [strokeLayer])
        
        // Create a polyline graphic with polyline and symbol created above.
        return Graphic(geometry: polylineBuilder.toGeometry(), symbol: lineSymbol)
    }
    
    // MARK: - Multilayer Polygons
    
    /// Creates the multilayer polygon graphics.
    /// - Returns: An `Array` of `Graphic`s.
    private func makeMultilayerPolygonGraphics() -> [Graphic] {
        // Create a text graphic.
        var graphics = [Graphic(
            geometry: Point(x: 65, y: 50, spatialReference: .wgs84),
            symbol: makeTextSymbol(text: "Multilayer\nPolygons")
        )]
        
        return graphics
    }
    
    // MARK: - More Multilayer Symbols
    
    /// Creates the more multilayer symbol graphics.
    /// - Returns: An `Array` of `Graphic`s.
    private func makeMoreMultilayerSymbolGraphics() -> [Graphic] {
        // Create a text graphic.
        var graphics = [Graphic(
            geometry: Point(x: 130, y: 50, spatialReference: .wgs84),
            symbol: makeTextSymbol(text: "More Multilayer\nSymbols")
        )]
        
        return graphics
    }
    
    // MARK: - MultilayerPoint Simple Markers
    
    /// Creates the multilayer point simple marker graphics.
    /// - Returns: An `Array` of `Graphic`s.
    private func makeMultilayerPointSimpleMarkerGraphics() -> [Graphic] {
        // Create a text graphic.
        var graphics = [Graphic(
            geometry: Point(x: -150, y: 50, spatialReference: .wgs84),
            symbol: makeTextSymbol(text: "MultilayerPoint\nSimple Markers")
        )]
        
        return graphics
    }
}

private extension URL {
    /// The URL to a campsite image on ArcGIS online.
    static let campsiteImage = URL(
        string: "https://static.arcgis.com/images/Symbols/OutdoorRecreation/Camping.png"
    )!
}
