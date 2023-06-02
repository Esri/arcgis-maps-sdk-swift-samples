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

struct CreateConvexHullAroundPointsView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// A Boolean indicate whether the create button can be pressed.
    @State private var createIsDisabled = true
    
    /// A Boolean indicate whether the reset button can be pressed.
    @State private var resetIsDisabled = true
    
    var body: some View {
        // Create a map view to display the map.
        MapView(map: model.map, graphicsOverlays: model.graphicsOverlays)
            .onSingleTapGesture { _, mapPoint in
                model.inputPoints.append(mapPoint)
                model.pointsGraphicsOverlay.addGraphic(Graphic(geometry: mapPoint, symbol: model.markerSymbol))
                createIsDisabled = false
                resetIsDisabled = false
            }
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    // Create button.
                    Button("Create") {
                        model.createConvexHull()
                        createIsDisabled = true
                    }
                    .disabled(createIsDisabled)
                    // Reset button.
                    Button("Reset") {
                        model.reset()
                        createIsDisabled = true
                        resetIsDisabled = true
                    }
                    .disabled(resetIsDisabled)
                }
            }
    }
}

private extension CreateConvexHullAroundPointsView {
    /// The view model for this sample.
    private class Model: ObservableObject {
        /// A map with a topographic basemap.
        let map = Map(basemapStyle: .arcGISTopographic)
        
        /// An array of input points to be used in creating the convexHull.
        var inputPoints: [Point] = []
        
        /// An array that contains the graphics overlays for the sample.
        var graphicsOverlays: [GraphicsOverlay] {
            [pointsGraphicsOverlay, convexHullGraphicsOverlay]
        }
        
        /// The graphics overlay for the input points graphics.
        let pointsGraphicsOverlay = GraphicsOverlay()
        
        /// The graphics overlay for the convex hull graphic.
        private let convexHullGraphicsOverlay = GraphicsOverlay()
        
        /// A red simple marker symbol to display where the user tapped on the map.
        let markerSymbol = SimpleMarkerSymbol(style: .circle, color: .red, size: 10)
        
        /// A blue simple line symbol for the outline of the convex hull graphic.
        private let lineSymbol = SimpleLineSymbol(style: .solid, color: .blue, width: 4)
        
        /// A hollow polygon simple fill symbol for the convex hull graphic.
        private lazy var fillSymbol = SimpleFillSymbol(style: .noFill, outline: lineSymbol)
        
        /// Reset the points and graphics.
        func reset() {
            inputPoints.removeAll()
            pointsGraphicsOverlay.removeAllGraphics()
            convexHullGraphicsOverlay.removeAllGraphics()
        }
        
        /// Create the convex hull graphic using the inputPoints.
        func createConvexHull() {
            // Normalize points.
            if let normalizedPoints = GeometryEngine.normalizeCentralMeridian(of: Multipoint(points: inputPoints)) {
                // Create convex hull geometry.
                if let convexHullGeometry = GeometryEngine.convexHull(for: normalizedPoints) {
                    // Set the symbol depending on the geometry type of the convex hull.
                    let symbol: Symbol?
                    switch convexHullGeometry {
                    case is Point:
                        symbol = markerSymbol
                    case is Polyline:
                        symbol = lineSymbol
                    case is Polygon:
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
}
