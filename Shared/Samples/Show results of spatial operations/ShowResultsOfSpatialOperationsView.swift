// Copyright 2022 Esri
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

import SwiftUI
import ArcGIS

struct ShowResultsOfSpatialOperationsView: View {
    /// The current spatial operation performed.
    @State private var spatialOperation = SpatialOperation.none
    
    /// A map with a topographic basemap style and initial viewpoint.
    @StateObject private var map = makeMap()
    
    /// A graphic representing the result of the spatial operation.
    @StateObject private var resultGraphic = makeResultGraphic()
    
    /// A graphics overlay for the map view.
    @StateObject private var graphicsOverlay = makeGraphicsOverlay()
    
    /// An enum of spatial operations.
    private enum SpatialOperation: CaseIterable {
        case none, union, difference, symmetricDifference, intersection
        /// Human readable label strings for each spatial operation.
        var label: String {
            switch self {
            case .none: return "None"
            case .union: return "Union"
            case .difference: return "Difference"
            case .symmetricDifference: return "Symmetric Difference"
            case .intersection: return "Intersection"
            }
        }
    }
    
    /// Creates a map.
    private static func makeMap() -> Map {
        let map = Map(basemapStyle: .arcGISTopographic)
        map.initialViewpoint = Viewpoint(
            center: Point(x: -13453, y: 6710127, spatialReference: .webMercator),
            scale: 30_000
        )
        return map
    }
    
    /// Creates a graphic for the result.
    private static func makeResultGraphic() -> Graphic {
        let lineSymbol = SimpleLineSymbol(style: .solid, color: .blue, width: 1)
        return Graphic(symbol: SimpleFillSymbol(style: .solid, color: .red, outline: lineSymbol))
    }
    
    /// Creates the graphics overlay.
    private static func makeGraphicsOverlay() -> GraphicsOverlay {
        let overlay = GraphicsOverlay()
        
        let lineSymbol = SimpleLineSymbol(style: .solid, color: .blue, width: 1)
        
        // Creates the graphics for the two polygons.
        let polygonOneGraphic = Graphic(
            geometry: .polygon1,
            symbol: SimpleFillSymbol(style: .solid, color: .blue, outline: lineSymbol)
        )
        
        let polygonTwoGraphic = Graphic(
            geometry: .polygon2,
            symbol: SimpleFillSymbol(style: .solid, color: .green, outline: lineSymbol)
        )
        
        // Adds the graphics to the overlay.
        overlay.addGraphics([polygonOneGraphic, polygonTwoGraphic])
        return overlay
    }
    
    /// Updates the result graphic based on the spatial operation.
    private func performOperation() {
        let resultGeometry: Geometry?
        // Updates the geometry based on the selected spatial operation.
        switch spatialOperation {
        case .none:
            resultGeometry = nil
        case .union:
            resultGeometry = GeometryEngine.union(.polygon1, .polygon2)
        case .difference:
            resultGeometry = GeometryEngine.difference(.polygon1, .polygon2)
        case .symmetricDifference:
            resultGeometry = GeometryEngine.symmetricDifference(.polygon1, .polygon2)
        case .intersection:
            resultGeometry = GeometryEngine.intersection(.polygon1, .polygon2)
        }
        // Updates the result graphic geometry.
        resultGraphic.geometry = resultGeometry
    }
    
    var body: some View {
        VStack {
            MapView(map: map, graphicsOverlays: [graphicsOverlay])
            
            Menu("Choose Operation") {
                Picker("Spatial Operation", selection: $spatialOperation) {
                    ForEach(SpatialOperation.allCases.reversed(), id: \.self) { operation in
                        Text(operation.label)
                    }
                }
            }
            .onChange(of: spatialOperation) { _ in
                performOperation()
            }
            .padding()
        }
        .onAppear {
            // Adds the result graphic to the graphics overlay.
            graphicsOverlay.addGraphic(resultGraphic)
        }
    }
}

private extension Geometry {
    /// The geometry for polygon one.
    static var polygon1: Geometry {
        Polygon(
            points: [
                Point(x: -13960, y: 6709400),
                Point(x: -14660, y: 6710000),
                Point(x: -13760, y: 6710730),
                Point(x: -13300, y: 6710500),
                Point(x: -13160, y: 6710100)
            ],
            spatialReference: .webMercator
        )
    }
    
    /// The geometry for polygon two.
    static var polygon2: Geometry {
        Polygon(
            parts: [
                // The outer ring
                MutablePart(
                    points: [
                        Point(x: -13060, y: 6711030),
                        Point(x: -12160, y: 6710730),
                        Point(x: -13160, y: 6709700),
                        Point(x: -14560, y: 6710730),
                        Point(x: -13060, y: 6711030)
                    ],
                    spatialReference: .webMercator
                ),
                // The inner ring.
                MutablePart(
                    points: [
                        Point(x: -13060, y: 6710910),
                        Point(x: -14160, y: 6710630),
                        Point(x: -13160, y: 6709900),
                        Point(x: -12450, y: 6710660),
                        Point(x: -13060, y: 6710910)
                    ],
                    spatialReference: .webMercator
                )
            ]
        )
    }
}
