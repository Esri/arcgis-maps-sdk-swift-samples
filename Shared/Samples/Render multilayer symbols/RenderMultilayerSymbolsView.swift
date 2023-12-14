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
    @State private var map: Map = {
        let map = Map(basemapStyle: .arcGISLightGray)
        map.initialViewpoint = Viewpoint(boundingGeometry: Point(x: -713_800, y: 0, spatialReference: .webMercator))
        return map
    }()
    
    /// The graphics overlay containing the multilayer graphics and associated text graphics.
    @State private var graphicsOverlay: GraphicsOverlay = {
        let graphicsOverlay = GraphicsOverlay()
        
        // Create graphics and add them to the graphics overlay.
        graphicsOverlay.addGraphics(makeMultilayerPointSimpleMarkerGraphics())
        graphicsOverlay.addGraphics(makeMultilayerPointPictureMarkerGraphics())
        graphicsOverlay.addGraphics(makeMultilayerPolylineGraphics())
        graphicsOverlay.addGraphics(makeMultilayerPolygonGraphics())
        graphicsOverlay.addGraphics(makeComplexMultilayerSymbolGraphics())
        
        return graphicsOverlay
    }()
    
    /// The offset used to keep a consistent distance between symbols in the same column.
    private static let offsetBetweenSymbols = 20.0
    
    var body: some View {
        MapView(map: map, graphicsOverlays: [graphicsOverlay])
    }
}

private extension RenderMultilayerSymbolsView {
    // MARK: Methods
    
    /// Creates a text symbol with the text to be displayed on the map.
    /// - Parameter text: The text used to create the text symbol.
    /// - Returns: A new `TextSymbol` object.
    private static func makeTextSymbol(text: String) -> TextSymbol {
        // Create text symbol with a white background.
        let textSymbol = TextSymbol(text: text, color: .black, size: 10)
        textSymbol.backgroundColor = .white
        return textSymbol
    }
    
    // MARK: MultilayerPoint Simple Markers
    
    /// Creates the multilayer point simple marker graphics.
    /// - Returns: The new `Graphic` objects to display on the map.
    private static func makeMultilayerPointSimpleMarkerGraphics() -> [Graphic] {
        // Create a text graphic.
        var graphics = [
            Graphic(
                geometry: Point(x: -150, y: 50, spatialReference: .wgs84),
                symbol: makeTextSymbol(text: "MultilayerPoint\nSimple Markers")
            )
        ]
        
        // Create a red diamond graphic from JSON and a multilayer polygon symbol.
        let redFillLayer = SolidFillSymbolLayer(color: .red)
        let polygonSymbol = MultilayerPolygonSymbol(symbolLayers: [redFillLayer])
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
                offset: offsetBetweenSymbols
            ))
        }
        
        // Create a cross graphic from JSON and a multilayer polyline symbol.
        let redStrokeLayer = SolidStrokeSymbolLayer(width: 1, color: .red)
        let polylineSymbol = MultilayerPolylineSymbol(symbolLayers: [redStrokeLayer])
        if let crossGeometry = try? Geometry.fromJSON(.crossGeometryJSON) {
            graphics.append(makeGraphicWithVectorMarkerSymbolElement(
                symbol: polylineSymbol,
                geometry: crossGeometry,
                offset: offsetBetweenSymbols * 2
            ))
        }
        
        return graphics
    }
    
    /// Creates a graphic of multilayer point symbol using a vector marker symbol element.
    /// - Parameters:
    ///   - symbol: The symbol to create the graphic of.
    ///   - geometry: The geometry used to make the vector marker symbol element.
    ///   - offset: The offset used to keep a consistent distance between symbols in the same column.
    /// - Returns: A new `Graphic` object of the multilayer point symbol.
    private static func makeGraphicWithVectorMarkerSymbolElement(
        symbol: MultilayerSymbol,
        geometry: Geometry,
        offset: Double
    ) -> Graphic {
        // Create a vector element using the passed symbol and geometry.
        let vectorElement = VectorMarkerSymbolElement(geometry: geometry, multilayerSymbol: symbol)
        
        // Create a vector layer using the vector element.
        let vectorLayer = VectorMarkerSymbolLayer(vectorMarkerSymbolElements: [vectorElement])
        
        // Create a point symbol using the vector layer.
        let pointSymbol = MultilayerPointSymbol(symbolLayers: [vectorLayer])
        
        // Create a graphic of the multilayer point symbol.
        return Graphic(geometry: Point(x: -150, y: 20 - offset, spatialReference: .wgs84), symbol: pointSymbol)
    }
    
    // MARK: MultilayerPoint Picture Markers
    
    /// Creates the multilayer point picture marker graphics .
    /// - Returns: The new `Graphic` objects to display on the map.
    private static func makeMultilayerPointPictureMarkerGraphics() -> [Graphic] {
        // Create a text graphic.
        var graphics = [
            Graphic(
                geometry: Point(x: -80, y: 50, spatialReference: .wgs84),
                symbol: makeTextSymbol(text: "MultilayerPoint\nPicture Markers")
            )
        ]
        
        // Create a campsite graphic using a URL.
        let campsiteLayer = PictureMarkerSymbolLayer(url: .campsiteImage)
        graphics.append(
            makeGraphicFromPictureMarkerSymbol(layer: campsiteLayer, offset: 0)
        )
        
        // Create a pin graphic using an image in the project assets.
        if let pinImage = UIImage(named: "PinBlueStar") {
            let pinLayer = PictureMarkerSymbolLayer(image: pinImage)
            graphics.append(
                makeGraphicFromPictureMarkerSymbol(layer: pinLayer, offset: 40)
            )
        }
        
        return graphics
    }
    
    /// Creates a graphic from a picture marker symbol layer using a multilayer point symbol.
    /// - Parameters:
    ///   - layer: The layer used to create the multilayer point symbol.
    ///   - offset: The offset used to keep a consistent distance between symbols in the same column.
    /// - Returns: A new `Graphic` object of the multilayer point symbol.
    private static func makeGraphicFromPictureMarkerSymbol(layer: PictureMarkerSymbolLayer, offset: Double) -> Graphic {
        // Create a multilayer point symbol using the picture marker symbol layer.
        layer.size = 40
        let symbol = MultilayerPointSymbol(symbolLayers: [layer])
        
        // Create the location for symbol using a point.
        let symbolPoint = Point(x: -80, y: 20 - offset, spatialReference: .wgs84)
        
        // Create the graphic for multilayer point symbol.
        return Graphic(geometry: symbolPoint, symbol: symbol)
    }
    
    // MARK: Multilayer Polylines
    
    /// Creates the multilayer polyline graphics.
    /// - Returns: The new `Graphic` objects to display on the map.
    private static func makeMultilayerPolylineGraphics() -> [Graphic] {
        // Create a text graphic.
        var graphics = [
            Graphic(
                geometry: Point(x: 0, y: 50, spatialReference: .wgs84),
                symbol: makeTextSymbol(text: "Multilayer\nPolylines")
            )
        ]
        
        // Create the polyline graphics.
        graphics.append(contentsOf: [
            // Dash, dot, dot.
            makeMultilayerPolylineSymbolGraphic(dashSpacing: [4, 6, 0.5, 6, 0.5, 6], offset: 0),
            // Dashes.
            makeMultilayerPolylineSymbolGraphic(dashSpacing: [4, 6], offset: offsetBetweenSymbols),
            // Dash, dot.
            makeMultilayerPolylineSymbolGraphic(dashSpacing: [7, 9, 0.5, 9], offset: offsetBetweenSymbols * 2)
        ])
        
        return graphics
    }
    
    /// Creates a graphic of a dashed multilayer polyline symbol.
    /// - Parameters:
    ///   - dashSpacing: The pattern of spaces and dashes used to create a dash effect.
    ///   - offset: The offset used to keep a consistent distance between symbols in the same column.
    /// - Returns: A new `Graphic` object of the multilayer polyline symbol.
    private static func makeMultilayerPolylineSymbolGraphic(dashSpacing: [Double], offset: Double) -> Graphic {
        // Create a dash effect with the passed dash spacing.
        let dashEffect = DashGeometricEffect(dashTemplate: dashSpacing)
        
        // Create a solid stroke symbol layer for the line symbol.
        let strokeLayer = SolidStrokeSymbolLayer(width: 3, color: .red, geometricEffects: [dashEffect])
        strokeLayer.capStyle = .round
        
        // Create a multilayer polyline symbol from the stroke layer.
        let lineSymbol = MultilayerPolylineSymbol(symbolLayers: [strokeLayer])
        
        // Create a polyline for the graphic.
        let polyline = Polyline(
            points: [
                Point(x: -30, y: 20 - offset),
                Point(x: 30, y: 20 - offset)
            ],
            spatialReference: .wgs84
        )
        
        // Create a graphic of the multilayer polyline symbol.
        return Graphic(geometry: polyline, symbol: lineSymbol)
    }
    
    // MARK: Multilayer Polygons
    
    /// Creates the multilayer polygon graphics.
    /// - Returns: The new `Graphic` objects to display on the map.
    private static func makeMultilayerPolygonGraphics() -> [Graphic] {
        // Create a text graphic.
        var graphics = [
            Graphic(
                geometry: Point(x: 65, y: 50, spatialReference: .wgs84),
                symbol: makeTextSymbol(text: "Multilayer\nPolygons")
            )
        ]
        
        // Create multilayer polygon symbols.
        graphics.append(contentsOf: [
            // Cross-hatched diagonal lines.
            makeMultilayerPolygonSymbolGraphic(angles: [-45, 45], offset: 0),
            // Hatched diagonal lines.
            makeMultilayerPolygonSymbolGraphic(angles: [-45], offset: offsetBetweenSymbols),
            // Hatched vertical lines.
            makeMultilayerPolygonSymbolGraphic(angles: [90], offset: offsetBetweenSymbols * 2)
        ])
        
        return graphics
    }
    
    /// Creates a graphic of a multilayer polygon symbol.
    /// - Parameters:
    ///   - angles: The angles at which to draw the fill lines within the polygon.
    ///   - offset: The offset used to keep a consistent distance between symbols in the same column.
    /// - Returns: A new `Graphic` object of the multilayer polygon symbol.
    private static func makeMultilayerPolygonSymbolGraphic(angles: [Double], offset: Double) -> Graphic {
        // Create a stroke symbol layer to make the symbol layer.
        let hatchStrokeLayer = SolidStrokeSymbolLayer(width: 2, color: .red)
        
        // Create a list to hold all necessary symbol layers.
        var symbolLayers: [SymbolLayer] = []
        
        // For each angle, create a hatch fill symbol layer with hatched lines at the given angle.
        for angle in angles {
            let hatchLayer = HatchFillSymbolLayer(
                polylineSymbol: MultilayerPolylineSymbol(symbolLayers: [hatchStrokeLayer]),
                angle: angle
            )
            
            // Set separation distance for lines.
            hatchLayer.separation = 9
            symbolLayers.append(hatchLayer)
        }
        
        // Create a stroke symbol layer to be used as an outline.
        let outlineStrokeLayer = SolidStrokeSymbolLayer(width: 1, color: .black)
        symbolLayers.append(outlineStrokeLayer)
        
        // Create a multilayer polygon symbol from the symbol layer list.
        let polygonSymbol = MultilayerPolygonSymbol(symbolLayers: symbolLayers)
        
        // Create rectangle polygon for the graphic.
        let polygon = Polygon(
            points: [
                Point(x: 60, y: 25 - offset),
                Point(x: 70, y: 25 - offset),
                Point(x: 70, y: 20 - offset),
                Point(x: 60, y: 20 - offset)
            ],
            spatialReference: .wgs84
        )
        
        // Create a graphic of the multilayer polygon symbol.
        return Graphic(geometry: polygon, symbol: polygonSymbol)
    }
    
    // MARK: Complex Multilayer Symbols
    
    /// Creates the complex multilayer symbol graphics.
    /// - Returns: The new `Graphic` objects to display on the map.
    private static func makeComplexMultilayerSymbolGraphics() -> [Graphic] {
        // Create a text graphic.
        var graphics = [
            Graphic(
                geometry: Point(x: 130, y: 50, spatialReference: .wgs84),
                symbol: makeTextSymbol(text: "Complex Multilayer\nSymbols")
            )
        ]
        
        // Create the complex multilayer graphics: a point, polygon and polyline.
        if let complexPointGeometry = try? Geometry.fromJSON(.complexPointGeometryJSON) {
            graphics.append(makeComplexPointGraphic(geometry: complexPointGeometry))
        }
        graphics.append(contentsOf: [
            makeComplexPolygonGraphic(),
            makeComplexPolylineGraphic()
        ])
        
        return graphics
    }
    
    /// Creates a graphic of a complex multilayer point from multiple symbol layers and given geometry.
    /// - Parameter geometry: The geometry used to create a multilayer polygon symbol.
    /// - Returns: A new `Graphic` object of the multilayer point symbol.
    private static func makeComplexPointGraphic(geometry: Geometry) -> Graphic {
        // Create the vector marker symbol layers for the complex point.
        let orangeSquareLayer = makeLayerForComplexPoint(fillColor: .orange, outlineColor: .blue, size: 11)
        orangeSquareLayer.anchor = SymbolAnchor(x: -4, y: -6, placementMode: .absolute)
        
        let blackSquareLayer = makeLayerForComplexPoint(fillColor: .black, outlineColor: .cyan, size: 6)
        blackSquareLayer.anchor = SymbolAnchor(x: 2, y: 1, placementMode: .absolute)
        
        let purpleSquareLayer = makeLayerForComplexPoint(fillColor: .clear, outlineColor: .magenta, size: 14)
        purpleSquareLayer.anchor = SymbolAnchor(x: 4, y: 2, placementMode: .absolute)
        
        // Create a layer of a yellow hexagon with a black outline from the passed geometry.
        let yellowFillLayer = SolidFillSymbolLayer(color: .yellow)
        let blackOutline = SolidStrokeSymbolLayer(width: 2, color: .black)
        let hexagonVectorElement = VectorMarkerSymbolElement(
            geometry: geometry,
            multilayerSymbol: MultilayerPolygonSymbol(symbolLayers: [yellowFillLayer, blackOutline])
        )
        let yellowHexagonLayer = VectorMarkerSymbolLayer(vectorMarkerSymbolElements: [hexagonVectorElement])
        yellowHexagonLayer.size = 35
        
        // Create the multilayer point symbol from the symbol layers.
        let pointSymbol = MultilayerPointSymbol(symbolLayers: [
            yellowHexagonLayer,
            orangeSquareLayer,
            blackSquareLayer,
            purpleSquareLayer
        ])
        
        // Create a graphic of the multilayer point symbol.
        return Graphic(geometry: Point(x: 130, y: 20, spatialReference: .wgs84), symbol: pointSymbol)
    }
    
    /// Creates a vector marker symbol layer for use in the composition of a complex point.
    /// - Parameters:
    ///   - fillColor: The fill color of the symbol.
    ///   - outlineColor: The  outline color of the symbol.
    ///   - size: The size of the symbol.
    /// - Returns: A new `VectorMarkerSymbolLayer` object of the created symbol.
    private static func makeLayerForComplexPoint(
        fillColor: UIColor,
        outlineColor: UIColor,
        size: Double
    ) -> VectorMarkerSymbolLayer {
        // Create a fill layer and outline.
        let fillLayer = SolidFillSymbolLayer(color: fillColor)
        let outlineLayer = SolidStrokeSymbolLayer(width: 2, color: outlineColor)
        
        // Create a geometry from an envelope.
        let geometry = Envelope(
            min: Point(x: -0.5, y: -0.5, spatialReference: .wgs84),
            max: Point(x: 0.5, y: 0.5, spatialReference: .wgs84)
        )
        
        // Create a vector marker symbol element using the geometry and a multilayer polygon symbol.
        let symbolElement = VectorMarkerSymbolElement(
            geometry: geometry,
            multilayerSymbol: MultilayerPolygonSymbol(symbolLayers: [fillLayer, outlineLayer])
        )
        
        // Create a symbol layer containing the symbol element.
        let symbolLayer = VectorMarkerSymbolLayer(vectorMarkerSymbolElements: [symbolElement])
        symbolLayer.size = size
        
        return symbolLayer
    }
    
    /// Creates a graphic of a complex polygon made with multiple symbol layers.
    /// - Returns: A new `Graphic` object of the multilayer polygon symbol.
    private static func makeComplexPolygonGraphic() -> Graphic {
        // Create a multilayer polygon symbol from the symbol layers.
        let polygonSymbol = MultilayerPolygonSymbol(
            symbolLayers: makeLayersForComplexMultilayerSymbols(includeRedFill: true)
        )
        
        // Create a polygon for the graphic.
        let polygon = Polygon(
            points: [
                Point(x: 120, y: 0),
                Point(x: 140, y: 0),
                Point(x: 140, y: -10),
                Point(x: 120, y: -10)
            ],
            spatialReference: .wgs84
        )
        
        // Create a graphic of the multilayer polygon symbol.
        return Graphic(geometry: polygon, symbol: polygonSymbol)
    }
    
    /// Creates a graphic of the complex polyline made with multiple layers.
    /// - Returns: A new `Graphic` object of the multilayer polyline symbol.
    private static func makeComplexPolylineGraphic() -> Graphic {
        // Create a multilayer polyline symbol from the symbol layers.
        let polylineSymbol = MultilayerPolylineSymbol(
            symbolLayers: makeLayersForComplexMultilayerSymbols(includeRedFill: false)
        )
        
        // Create a polyline geometry of the graphic.
        let polyline = Polyline(
            points: [
                Point(x: 120, y: -25),
                Point(x: 140, y: -25)
            ],
            spatialReference: .wgs84
        )
        
        // Create a graphic of the multilayer polygon symbol.
        return Graphic(geometry: polyline, symbol: polylineSymbol)
    }
    
    /// Creates the symbol layers used to create the complex multilayer symbols.
    /// - Parameter includeRedFill: A Boolean that indicates whether to include a red fill layer.
    /// - Returns: The new `SymbolLayer` objects.
    private static func makeLayersForComplexMultilayerSymbols(includeRedFill: Bool) -> [SymbolLayer] {
        // Create a black dash effect.
        let dashEffect = DashGeometricEffect(dashTemplate: [5, 3])
        let blackDashesLayer = SolidStrokeSymbolLayer(width: 1, color: .black, geometricEffects: [dashEffect])
        blackDashesLayer.capStyle = .square
        
        // Create a black outline.
        let blackOutlineLayer = SolidStrokeSymbolLayer(width: 7, color: .black)
        blackOutlineLayer.capStyle = .round
        
        // Create a yellow stroke.
        let yellowStrokeLayer = SolidStrokeSymbolLayer(width: 5, color: .yellow)
        yellowStrokeLayer.capStyle = .round
        
        let symbolLayers = [blackOutlineLayer, yellowStrokeLayer, blackDashesLayer]
        return includeRedFill ? symbolLayers + [SolidFillSymbolLayer(color: .red)] : symbolLayers
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
    static let complexPointGeometryJSON = "{\"rings\":[[[-2.89,5],[2.89,5],[5.77,0],[2.89,-5],[-2.89,-5],[-5.77,0],[-2.89,5]]]}"
    
    /// The JSON for a diamond geometry.
    static let diamondGeometryJSON = "{\"rings\":[[[0,2.5],[2.5,0],[0,-2.5],[-2.5,0],[0,2.5]]]}"
    
    /// The JSON for a triangle geometry.
    static let triangleGeometryJSON = "{\"rings\":[[[0,5],[5,-5],[-5,-5],[0,5]]]}"
    
    /// The JSON for a cross geometry.
    static let crossGeometryJSON = "{\"paths\":[[[-1,1],[0,0],[1,-1]],[[1,1],[0,0],[-1,-1]]]}"
}

#Preview {
    RenderMultilayerSymbolsView()
}
