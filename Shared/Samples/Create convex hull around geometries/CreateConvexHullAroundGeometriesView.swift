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
    /// A map with a topographic basemap.
    @State private var map = Map(basemapStyle: .arcGISTopographic)
    
    /// The graphics overlay for the geometry graphics.
    @State private var geometriesGraphicsOverlay: GraphicsOverlay = {
        let polygonFillSymbol = SimpleFillSymbol(
            style: .forwardDiagonal,
            color: .systemBlue,
            outline: SimpleLineSymbol(style: .solid, color: .blue, width: 2)
        )
        
        // Create graphics for the example polygons.
        let polygonGraphic1 = Graphic(geometry: .polygon1, symbol: polygonFillSymbol)
        let polygonGraphic2 = Graphic(geometry: .polygon2, symbol: polygonFillSymbol)
        return GraphicsOverlay(graphics: [polygonGraphic1, polygonGraphic2])
    }()
    
    /// The graphics overlay for the convex hull graphics.
    @State private var convexHullGraphicsOverlay = GraphicsOverlay()
    
    /// A Boolean indicating whether the button is set to create.
    @State private var createIsOn = true
    
    /// A Boolean indicating whether the convex hull geometries should union.
    @State private var shouldUnion = false
    
    var body: some View {
        MapView(map: map, graphicsOverlays: [convexHullGraphicsOverlay, geometriesGraphicsOverlay])
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Toggle(shouldUnion ? "Union Enabled" : "Union Disabled", isOn: $shouldUnion)
                        .disabled(convexHullGraphicsOverlay.graphics.isEmpty)
                        .onChange(of: shouldUnion) { _ in
                            if !createIsOn {
                                convexHullGraphicsOverlay.removeAllGraphics()
                                convexHullGraphicsOverlay.addGraphics(
                                    makeConvexHullGraphics(
                                        for: [.polygon1, .polygon2],
                                        unioned: shouldUnion
                                    )
                                )
                            }
                        }
                    Button(createIsOn ? "Create" : "Reset") {
                        if createIsOn {
                            convexHullGraphicsOverlay.removeAllGraphics()
                            convexHullGraphicsOverlay.addGraphics(
                                makeConvexHullGraphics(
                                    for: [.polygon1, .polygon2],
                                    unioned: shouldUnion
                                )
                            )
                            createIsOn = false
                        } else {
                            convexHullGraphicsOverlay.removeAllGraphics()
                            createIsOn = true
                        }
                    }
                }
            }
    }
}

private extension CreateConvexHullAroundGeometriesView {
    /// Creates convex hulls graphic(s) from passed geometries.
    /// - Parameters:
    ///   - geometries: A `Geometry Array` to create the convex hull geometries from.
    ///   - unioned: A `Bool` indicating whether to union the convex hull geometries.
    /// - Returns: A `Graphics Array` of the created convex hull graphic(s).
    func makeConvexHullGraphics(for geometries: [Geometry], unioned: Bool) -> [Graphic] {
        // Create convex hull geometries.
        let convexHullGeometries = GeometryEngine.convexHull(for: geometries, shouldMerge: unioned)
        
        // Create fill symbol for the convex hull graphics.
        let convexHullFillSymbol = SimpleFillSymbol(
            style: .noFill,
            color: .systemBlue,
            outline: SimpleLineSymbol(style: .solid, color: .red, width: 4)
        )
        
        // Create a graphic for each convex hull geometry.
        var graphics: [Graphic] = []
        for geometry in convexHullGeometries {
            let convexHullGraphic = Graphic(geometry: geometry, symbol: convexHullFillSymbol)
            graphics.append(convexHullGraphic)
        }
        return graphics
    }
}

private extension Geometry {
    /// Example polygon 1.
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
    
    /// Example polygon 2.
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

#Preview {
    NavigationView {
        CreateConvexHullAroundGeometriesView()
    }
}
