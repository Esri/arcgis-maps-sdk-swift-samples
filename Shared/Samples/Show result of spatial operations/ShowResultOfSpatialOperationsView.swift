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

struct ShowResultOfSpatialOperationsView: View {
    /// The current spatial operation performed.
    @State private var spatialOperation = SpatialOperation.none
    
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    var body: some View {
        MapView(map: model.map, graphicsOverlays: [model.graphicsOverlay])
            .onChange(of: spatialOperation) { _ in
                model.performOperation(spatialOperation)
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Picker("Spatial Operation", selection: $spatialOperation) {
                        ForEach(SpatialOperation.allCases, id: \.self) { operation in
                            Text(operation.label)
                        }
                    }
                }
            }
    }
}

private extension ShowResultOfSpatialOperationsView {
    /// An enum of spatial operations.
    enum SpatialOperation: CaseIterable {
        case intersection, symmetricDifference, difference, union, none
        
        /// A human-readable label for each spatial operation.
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
    
    /// The model used to store the geo model and other expensive objects
    /// used in this view.
    class Model: ObservableObject {
        /// A map with a topographic basemap style and initial viewpoint.
        let map: Map = {
            let map = Map(basemapStyle: .arcGISTopographic)
            map.initialViewpoint = Viewpoint(
                center: Point(x: -13453, y: 6710127, spatialReference: .webMercator),
                scale: 30_000
            )
            return map
        }()
        
        /// A graphics overlay for the map view.
        let graphicsOverlay: GraphicsOverlay = {
            // Creates the graphics for the two polygons and result.
            let polygonOneGraphic = Graphic(
                geometry: .polygon1,
                symbol: SimpleFillSymbol(color: .blue, outline: .simple)
            )
            
            let polygonTwoGraphic = Graphic(
                geometry: .polygon2,
                symbol: SimpleFillSymbol(color: .green, outline: .simple)
            )
            
            let resultGraphic = Graphic(
                symbol: SimpleFillSymbol(color: .red, outline: .simple)
            )
            
            // Adds the graphics to the overlay.
            return GraphicsOverlay(graphics: [polygonOneGraphic, polygonTwoGraphic, resultGraphic])
        }()
        
        /// A graphic representing the result of the spatial operation.
        var resultGraphic: Graphic { graphicsOverlay.graphics.last! }
        
        /// Updates the result graphic based on the spatial operation.
        func performOperation(_ spatialOperation: SpatialOperation) {
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
    }
}

private extension LineSymbol {
    /// A solid, thin, black line.
    static var simple: LineSymbol {
        SimpleLineSymbol(style: .solid, color: .black, width: 1)
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
                // The outer ring.
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

#if DEBUG
private extension ShowResultOfSpatialOperationsView.Model {
    typealias SpatialOperation = ShowResultOfSpatialOperationsView.SpatialOperation
}

#Preview {
    NavigationView {
        ShowResultOfSpatialOperationsView()
    }
}
#endif
