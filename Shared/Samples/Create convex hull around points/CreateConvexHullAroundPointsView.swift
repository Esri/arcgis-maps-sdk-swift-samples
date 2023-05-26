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

    var body: some View {
        // Create a map view to display the map.
        MapView(map: model.map, graphicsOverlays: [model.graphicsOverlay])
            .onSingleTapGesture { _, mapPoint in
                model.graphicsOverlay.addGraphic(Graphic(geometry: mapPoint, symbol: model.markerSymbol))
            }
            .toolbar {
                // Create button for
                ToolbarItem(placement: .bottomBar) {
                    Button("Create") {
                        model.createConvexHull()
                    }
                    .disabled(model.createIsDisabled)
                }
                // Reset button.
                ToolbarItem(placement: .bottomBar) {
                    Button("Reset") {
                    }
                    .disabled(model.resetIsDisabled)
                }
            }
            .alert(isPresented: $model.isShowingAlert, presentingError: model.error)
    }
}

private extension CreateConvexHullAroundPointsView {
    // The view model for this sample.
    private class Model: ObservableObject {
        /// The graphics overlay for the convex hull and points.
        let graphicsOverlay = GraphicsOverlay()
        
        /// A simple marker symbol to display where the user tapped/clicked on the map.
        let markerSymbol = SimpleMarkerSymbol(style: .circle, color: .red, size: 10)
        
        /// A simple line symbol for the outline of the convex hull graphic(s).
        let lineSymbol = SimpleLineSymbol(style: .solid, color: .blue, width: 4)
        
        /// A simple fill symbol for the convex hull graphic(s) - a hollow polygon with a thick red outline.
        lazy var fillSymbol = SimpleFillSymbol(color: .red, outline: lineSymbol)
        
        /// The graphic for the convex hull.
        var convexHullGraphic: Graphic?
        
        /// An Array of inputteed points to be used in creating the convexHull.
        var inputPoints: [Point] = []
        
        
        /// A Boolean value indicating whether to show an alert.
        @Published var isShowingAlert = false
        
        /// The error shown in the alert.
        @Published var error: Error? {
            didSet { isShowingAlert = error != nil }
        }
        
        /// A Bool indicate whether the create button can be pressed.
        @State var createIsDisabled = false
        
        /// A Bool indicate whether the reset button can be pressed.
        @State var resetIsDisabled = true
        
        /// A map with a topographic basemap.
        var map: Map = {
            let map = Map(basemapStyle: .arcGISTopographic)
            return map
        }()
        
        /// Called in response to the Create convex hull button being tapped.
        func createConvexHull() {
            if let normalizedPoints = GeometryEngine.normalizeCentralMeridian(of: Multipoint(points: inputPoints)),
               let convexHullGeometry = GeometryEngine.convexHull(for: normalizedPoints) {
                // Set the symbol depending on the geometry type of the convex hull.
                let symbol: Symbol
                switch convexHullGeometry {
                case is Point:
                    symbol = markerSymbol
                case is Polyline:
                    symbol = lineSymbol
                default:
                    symbol = fillSymbol
                }
                
                // Remove the existing graphic for convex hull if there is one.
                if let existingGraphic = convexHullGraphic {
                    graphicsOverlay.removeGraphic(existingGraphic)
                }
                
                let graphic = Graphic(geometry: convexHullGeometry, symbol: symbol)
                convexHullGraphic = graphic
                graphicsOverlay.addGraphic(convexHullGraphic!)
                print("ran")
                // $createIsDisabled.toggle()
            } else {
                // Present an alert if there is a problem with the
                // AGSGeometryEngine operations.
                // error = Error("Geometry Engine Failed!")
                print("error")
            }
        }
    }
}
