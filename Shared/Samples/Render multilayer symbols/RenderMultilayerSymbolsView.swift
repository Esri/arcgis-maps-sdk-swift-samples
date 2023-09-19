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
        graphics.append(contentsOf: makeComplexMultilayerSymbolGraphics())
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
        let textSymbol = TextSymbol(text: text, color: .black, size: 10)
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
    
    /// Creates a graphic from picture marker symbol layer using a multilayer point symbol.
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
            makeMultilayerPolylineSymbolGraphic(dashSpacing: [7.0, 9.0, 0.5, 9.0], offset: offset * 2)
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
        
        // Create polygon marker symbols
        graphics.append(contentsOf: [
            // Cross-hatched diagonal lines.
            makeMultilayerPolygonSymbolGraphic(angles: [-45, 45], offset: 0),
            // Hatched diagonal lines.
            makeMultilayerPolygonSymbolGraphic(angles: [-45], offset: offset),
            // Hatched vertical lines.
            makeMultilayerPolygonSymbolGraphic(angles: [90], offset: offset * 2)
        ])
        
        return graphics
    }
    
    /// Creates a graphic of a multilayer polygon symbol.
    /// - Parameters:
    ///   - angles: The angle at which to draw the fill lines within the polygon.
    ///   - offset: The `Double` used to keep a consistent distance between symbols in the same column.
    /// - Returns: A new `Graphic` object.
    private func makeMultilayerPolygonSymbolGraphic(angles: [Double], offset: Double) -> Graphic {
        let polygonBuilder = PolygonBuilder(spatialReference: .wgs84)
        polygonBuilder.add(Point(x: 60, y: 25 - offset))
        polygonBuilder.add(Point(x: 70, y: 25 - offset))
        polygonBuilder.add(Point(x: 70, y: 20 - offset))
        polygonBuilder.add(Point(x: 60, y: 20 - offset))
        
        // Create a stroke symbol layer to be used by patterns.
        let strokeForHatches = SolidStrokeSymbolLayer(width: 2, color: .red)
        
        // Create a stroke symbol layer to be used as an outline for aforementioned patterns
        let strokeForOutline = SolidStrokeSymbolLayer(width: 1, color: .black)
        
        // Create a list to hold all necessary symbol layers
        // At least one for patterns and one for an outline at the end
        var symbolLayerList: [SymbolLayer] = []
        
        // For each angle, create a symbol layer using the pattern stroke
        // with hatched lines at the given angle
        for angle in angles {
            let hatchLayer = HatchFillSymbolLayer(
                polylineSymbol: MultilayerPolylineSymbol(symbolLayers: [strokeForHatches]),
                angle: angle
            )
            // Set separation distance for line and add to to the symbol layer list.
            hatchLayer.separation = 9.0
            symbolLayerList.append(hatchLayer)
        }
        
        // Set the last element of the symbol layer list to the outline layer.
        symbolLayerList.append(strokeForOutline)
        
        // Create a multilayer polygon symbol from the symbol layer list.
        let polygonSymbol = MultilayerPolygonSymbol(symbolLayers: symbolLayerList)
        
        // Create a graphic with using the polygon builder and polygon symbol.
        return Graphic(geometry: polygonBuilder.toGeometry(), symbol: polygonSymbol)
    }
    
    // MARK: - Complex Multilayer Symbols
    
    /// Creates the more complex multilayer symbol graphics.
    /// - Returns: An `Array` of `Graphic`s.
    private func makeComplexMultilayerSymbolGraphics() -> [Graphic] {
        // Create a text graphic.
        var graphics = [Graphic(
            geometry: Point(x: 130, y: 50, spatialReference: .wgs84),
            symbol: makeTextSymbol(text: "Complex Multilayer\nSymbols")
        )]
        
        // Create more complex multilayer graphics: a point, polygon and polyline.
        if let complexPointGeometry = try? Geometry.fromJSON(.complexPointGeometryJSON) {
            graphics.append(makeComplexPointGraphic(geometry: complexPointGeometry))
        }
        
        graphics.append(contentsOf: [
            makeComplexPolygonGraphic(),
            makeComplexPolylineGraphic()
        ])
        return graphics
    }
    
    /// Creates a graphic of a complex multilayer point from multiple symbol layers and a provide geometry.
    /// - Parameter geometry: The `Geometry` to create the `MultilayerPolygonSymbol` from.
    /// - Returns: A new `Graphic` object of the symbol. 
    private func makeComplexPointGraphic(geometry: Geometry) -> Graphic {
        // Create the marker layers for the complex point.
        let orangeSquareLayer = makeLayerForComplexPoint(fillColor: .cyan, outlineColor: .blue, size: 11)
        orangeSquareLayer.anchor = SymbolAnchor(x: -4, y: -6, placementMode: .absolute)
        
        let blackSquareLayer = makeLayerForComplexPoint(fillColor: .black, outlineColor: .cyan, size: 6)
        blackSquareLayer.anchor = SymbolAnchor(x: 2, y: 1, placementMode: .absolute)
        
        let purpleSquareLayer = makeLayerForComplexPoint(fillColor: .clear, outlineColor: .magenta, size: 14)
        purpleSquareLayer.anchor = SymbolAnchor(x: 4, y: 2, placementMode: .absolute)
        
        // Create a layer of a yellow hexagon with a black outline.
        let yellowFillLayer = SolidFillSymbolLayer(color: .yellow)
        let blackOutline = SolidStrokeSymbolLayer(width: 2, color: .black)
        let hexagonVectorElement = VectorMarkerSymbolElement(
            geometry: geometry,
            multilayerSymbol: MultilayerPolygonSymbol(symbolLayers: [yellowFillLayer, blackOutline])
        )
        
        let yellowHexagonLayer = VectorMarkerSymbolLayer(vectorMarkerSymbolElements: [hexagonVectorElement])
        yellowHexagonLayer.size = 35
        
        // Create the multilayer point symbol from the layers
        let pointSymbol = MultilayerPointSymbol(symbolLayers: [
            yellowHexagonLayer,
            orangeSquareLayer,
            blackSquareLayer,
            purpleSquareLayer
        ])
        
        // Create a graphic of the multilayer point symbol.
        return Graphic(geometry: Point(x: 130, y: 20, spatialReference: .wgs84), symbol: pointSymbol)
    }
    
    /// Creates a symbol layer for use in the composition of a complex point.
    /// - Parameters:
    ///   - fillColor: The `UIColor` to create the `VectorMarkerSymbolLayer.`
    ///   - outlineColor: The `UIColor` to create the `SolidStrokeSymbolLayer.`
    ///   - size: The `Double` size of the symbol.
    /// - Returns: A new `VectorMarkerSymbolLayer` object of the created symbol.
    private func makeLayerForComplexPoint(
        fillColor: UIColor, outlineColor: UIColor, size: Double
    ) -> VectorMarkerSymbolLayer {
        // Create a fill layer and outline.
        let fillLayer = SolidFillSymbolLayer(color: fillColor)
        let outline = SolidStrokeSymbolLayer(width: 2, color: outlineColor)
        
        // Create a geometry from an envelope.
        let geometry = Envelope(
            min: Point(x: -0.5, y: -0.5, spatialReference: .wgs84),
            max: Point(x: 0.5, y: 0.5, spatialReference: .wgs84)
        )
        
        // Create a symbol element using the geometry, fill layer, and outline.
        let symbolElement = VectorMarkerSymbolElement(
            geometry: geometry,
            multilayerSymbol: MultilayerPolygonSymbol(symbolLayers: [fillLayer, outline])
        )
        
        // Create a symbol layer containing just the above symbol element, set its size, and return it
        let symbolLayer = VectorMarkerSymbolLayer(vectorMarkerSymbolElements: [symbolElement])
        symbolLayer.size = size
        return symbolLayer
    }
    
    /// Creates a graphic of a complex polygon made with multiple symbol layers.
    /// - Returns: A new `Graphic` object.
    private func makeComplexPolygonGraphic() -> Graphic {
        // Create a multilayer polygon symbol from the symbol layers.
        let polygonSymbol = MultilayerPolygonSymbol(
            symbolLayers: makeLayersForComplexMultilayerSymbols(includeRedFill: true)
        )
        
        // Create a polygon
        let polygonBuilder = PolygonBuilder(spatialReference: .wgs84)
        polygonBuilder.add(Point(x: 120, y: 0))
        polygonBuilder.add(Point(x: 140, y: 0))
        polygonBuilder.add(Point(x: 140, y: -10))
        polygonBuilder.add(Point(x: 120, y: -10))
        
        // Create a multilayer polygon graphic with the polygon builder and polygon symbol.
        return Graphic(geometry: polygonBuilder.toGeometry(), symbol: polygonSymbol)
    }
    
    private func makeComplexPolylineGraphic() -> Graphic {
        // Create a multilayer polyline symbol from the symbol layers.
        let polylineSymbol = MultilayerPolylineSymbol(
            symbolLayers: makeLayersForComplexMultilayerSymbols(includeRedFill: true)
        )
        
        // Create a polyline
        let polylineBuilder = PolylineBuilder(spatialReference: .wgs84)
        polylineBuilder.add(Point(x: 120, y: -25))
        polylineBuilder.add(Point(x: 140, y: -25))
        
        // Create the multilayer polyline graphic with the geometry and symbol.
        return Graphic(geometry: polylineBuilder.toGeometry(), symbol: polylineSymbol)
    }
    
    /// Creates the symbol layers used to create the complex multilayer symbols.
    /// - Parameter includeRedFill: A `Bool` that indicates whether to include a red fill layer.
    /// - Returns: An `Array` of `SymbolLayers`s.
    private func makeLayersForComplexMultilayerSymbols(includeRedFill: Bool) -> [SymbolLayer] {
        // Create a black dash effect.
        let dashEffect = DashGeometricEffect(dashTemplate: [5.0, 3.0])
        let blackDashes = SolidStrokeSymbolLayer(width: 1, color: .black, geometricEffects: [dashEffect])
        blackDashes.capStyle = .square
        
        // Create a black outline.
        let blackOutline = SolidStrokeSymbolLayer(width: 7, color: .black)
        blackOutline.capStyle = .round
        
        // Create a yellow stroke.
        let yellowStroke = SolidStrokeSymbolLayer(width: 5, color: .yellow)
        yellowStroke.capStyle = .round
        
        if includeRedFill {
            // Create a red fill layer for the polygon.
            let redFillLayer = SolidFillSymbolLayer(color: .red)
            return [redFillLayer, blackOutline, yellowStroke, blackDashes]
        }
        
        return [blackOutline, yellowStroke, blackDashes]
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
        
        // Create a red diamond graphic from JSON and a multilayer polygon symbol.
        let fillLayer = SolidFillSymbolLayer(color: .red)
        let polygonSymbol = MultilayerPolygonSymbol(symbolLayers: [fillLayer])
        if let diamondGeometry = try? Geometry.fromJSON(.diamondGeometryJSON) {
            graphics.append(makeGraphicWithVectorMarkerSymbolElement(
                symbol: polygonSymbol,
                geometry: diamondGeometry,
                offset: 0
            ))
        }
        
        // Create a triangle graphic from JSON and a multilayer polygon symbol.
        if let triangleGeometry = try? Geometry.fromJSON(.triangleGeometryJSON) {
            graphics.append(makeGraphicWithVectorMarkerSymbolElement(
                symbol: polygonSymbol,
                geometry: triangleGeometry,
                offset: offset
            ))
        }
        
        // Create a cross graphic from JSON and a multilayer polyline symbol.
        let strokeLayer = SolidStrokeSymbolLayer(width: 1, color: .red)
        let polylineSymbol = MultilayerPolylineSymbol(symbolLayers: [strokeLayer])
        if let crossGeometry = try? Geometry.fromJSON(.crossGeometryJSON) {
            graphics.append(makeGraphicWithVectorMarkerSymbolElement(
                symbol: polylineSymbol,
                geometry: crossGeometry,
                offset: offset * 2
            ))
        }
        return graphics
    }
    
    /// Creates a graphic using a vector marker symbol element.
    /// - Parameters:
    ///   - symbol: The `MultilayerSymbol` used to make the `VectorMarkerSymbolElement`.
    ///   - geometry: The `Geometry` used to make the `VectorMarkerSymbolElement`.
    ///   - offset: The `Double` used to keep a consistent distance between symbols in the same column.
    /// - Returns: A new `Graphic` object.
    private func makeGraphicWithVectorMarkerSymbolElement(
        symbol: MultilayerSymbol, geometry: Geometry, offset: Double
    ) -> Graphic {
        // Create a vector element using the passed symbol and geometry.
        let vectorElement = VectorMarkerSymbolElement(geometry: geometry, multilayerSymbol: symbol)
        
        // Create a vector layer using the vector element.
        let vectorLayer = VectorMarkerSymbolLayer(vectorMarkerSymbolElements: [vectorElement])
        
        // Create a point symbol using the vector layer.
        let pointSymbol = MultilayerPointSymbol(symbolLayers: [vectorLayer])
        
        // Create a point graphic using the point symbol.
        return Graphic(
            geometry: Point(x: -150, y: 20 - offset, spatialReference: .wgs84),
            symbol: pointSymbol
        )
    }
}

private extension URL {
    /// The URL to a campsite image on ArcGIS online.
    static let campsiteImage = URL(
        string: "https://static.arcgis.com/images/Symbols/OutdoorRecreation/Camping.png"
    )!
}

private extension String {
    /// The JSON for a complex point geometry.
    static let complexPointGeometryJSON = "{\"rings\":[[[-2.89,5.0],[2.89,5.0],[5.77,0.0],[2.89,-5.0],[-2.89,-5.0],[-5.77,0.0],[-2.89,5.0]]]}"
    
    /// The JSON for a diamond geometry.
    static let diamondGeometryJSON = "{\"rings\":[[[0.0,2.5],[2.5,0.0],[0.0,-2.5],[-2.5,0.0],[0.0,2.5]]]}"
    
    /// The JSON for a triangle geometry.
    static let triangleGeometryJSON = "{\"rings\":[[[0.0,5.0],[5,-5.0],[-5,-5.0],[0.0,5.0]]]}"
    
    /// The JSON for a cross geometry.
    static let crossGeometryJSON = "{\"paths\":[[[-1,1],[0,0],[1,-1]],[[1,1],[0,0],[-1,-1]]]}"
}
