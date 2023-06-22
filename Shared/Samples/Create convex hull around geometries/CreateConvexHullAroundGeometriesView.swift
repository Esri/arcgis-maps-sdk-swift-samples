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

struct CreateConvexHullAroundGeometriesView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// A Boolean value indicating whether the create button can be pressed.
    @State private var createIsDisabled = true
    
    /// A Boolean indicate whether the reset button can be pressed.
    @State private var resetIsDisabled = true
    
    var body: some View {
        // Create a map view to display the map.
        MapView(map: model.map, graphicsOverlays: model.graphicsOverlays)
            .onSingleTapGesture { _, mapPoint in
                model.inputPoints.append(mapPoint)
                model.geometriesGraphicsOverlay.addGraphic(Graphic(geometry: mapPoint))
                createIsDisabled = false
                resetIsDisabled = false
            }
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button("Create") {
                        model.createConvexHull()
                        createIsDisabled = true
                    }
                    .disabled(createIsDisabled)
                    Button("Reset") {
                        model.convexHullGraphicsOverlay.removeAllGraphics()
                        createIsDisabled = true
                        resetIsDisabled = true
                    }
                    .disabled(resetIsDisabled)
                }
            }
    }
}

private extension CreateConvexHullAroundGeometriesView {
    /// The view model for this sample.
    private class Model: ObservableObject {
        /// A map with a topographic basemap.
        let map = Map(basemapStyle: .arcGISTopographic)
        
        /// An array of input points to be used in creating the convexHull.
        var inputPoints: [Point] = []
        
        /// An array that contains the graphics overlays for the sample.
        var graphicsOverlays: [GraphicsOverlay] {
            return [geometriesGraphicsOverlay, convexHullGraphicsOverlay]
        }
        
        /// The graphics overlay for the input points graphics.
        let geometriesGraphicsOverlay: GraphicsOverlay = {
            let polygonFillSymbol = SimpleFillSymbol(
                style: .forwardDiagonal,
                color: .systemBlue,
                outline: SimpleLineSymbol(style: .solid, color: .blue, width: 2)
            )
            let polygonGraphic1 = Graphic(
                geometry: .polygon1,
                symbol: polygonFillSymbol
            )
            polygonGraphic1.zIndex = 1
            let polygonGraphic2 = Graphic(
                geometry: .polygon2,
                symbol: polygonFillSymbol
            )
            polygonGraphic2.zIndex = 1
            return GraphicsOverlay(graphics: [polygonGraphic1, polygonGraphic2])
        }()
        
        /// The graphics overlay for the convex hull graphic.
        let convexHullGraphicsOverlay = GraphicsOverlay()
        
        /// A red simple marker symbol to display where the user tapped on the map.
        private let markerSymbol: SimpleMarkerSymbol
        
        /// A blue simple line symbol for the outline of the convex hull graphic.
        private let lineSymbol: SimpleLineSymbol
        
        /// A hollow polygon simple fill symbol for the convex hull graphic.
        private var fillSymbol: SimpleFillSymbol
        
        init() {
            markerSymbol = SimpleMarkerSymbol(style: .circle, color: .red, size: 10)
            lineSymbol = SimpleLineSymbol(style: .solid, color: .blue, width: 4)
            fillSymbol = SimpleFillSymbol(style: .noFill, outline: lineSymbol)
        }
        
        /// Create the convex hull graphic using the inputPoints.
        func createConvexHull() {
            // Normalize points and create convex hull geometry.
            if let normalizedPoints = GeometryEngine.normalizeCentralMeridian(of: Multipoint(points: inputPoints)),
               let convexHullGeometry = GeometryEngine.convexHull(for: normalizedPoints) {
                // Set the symbol depending on the geometry type of the convex hull.
                let symbol: Symbol?
                switch convexHullGeometry {
                case is Point:
                    symbol = markerSymbol
                case is Polyline:
                    symbol = lineSymbol
                case is ArcGIS.Polygon:
                    symbol = fillSymbol
                default:
                    symbol = nil
                }
                
                // Remove the existing graphic for convex hull.
                convexHullGraphicsOverlay.removeAllGraphics()
                
                // Create the convex hull graphic.
                let convexHullGraphic = Graphic(geometry: convexHullGeometry, symbol: symbol)
                convexHullGraphicsOverlay.addGraphic(convexHullGraphic)
            }
        }
    }
}

private extension Geometry {
    /// An example polygon.
    static let polygon1: ArcGIS.Polygon = Polygon(
        points: [
            Point(x: -4983189.15470412, y: 8679428.55774286),
            Point(x: -5222621.66664186, y: 5147799.00666126),
            Point(x: -13483043.3284937, y: 4728792.11077023),
            Point(x: -13273539.8805482, y: 2244679.79941622),
            Point(x: -5372266.98660294, y: 2035176.3514707),
            Point(x: -5432125.11458738, y: -4100281.76693377),
            Point(x: -2469147.7793579, y: -4160139.89491821),
            Point(x: -1900495.56350578, y: 2035176.3514707),
            Point(x: 2768438.41928007, y: 1975318.22348627),
            Point(x: 2409289.65137346, y: 5477018.71057565),
            Point(x: -2409289.65137346, y: 5387231.518599),
            Point(x: -2469147.7793579, y: 8709357.62173508)
        ],
        spatialReference: .webMercator
    )
    
    /// An example polygon.
    static let polygon2: ArcGIS.Polygon = Polygon(
        points: [
            Point(x: 5993520.19456882, y: -1063938.49607736),
            Point(x: 3085421.63862418, y: -1383120.04490055),
            Point(x: 3794713.96934239, y: -2979027.78901651),
            Point(x: 6880135.60796657, y: -4078430.90162972),
            Point(x: 7092923.30718203, y: -2837169.32287287),
            Point(x: 8617901.81822617, y: -2092412.37561875),
            Point(x: 6986529.4575743, y: 354646.16535905),
            Point(x: 5319692.48038653, y: 1205796.96222089)
        ],
        spatialReference: .webMercator
    )
}
