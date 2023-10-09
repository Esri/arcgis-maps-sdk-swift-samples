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

struct IdentifyGraphicsView: View {
    /// A map with a topographic basemap.
    @State private var map = Map(basemapStyle: .arcGISTopographic)
    
    /// A graphics overlay containing a yellow polygon graphic.
    @State private var graphicsOverlay = {
        let graphicsOverlay = GraphicsOverlay()
        
        // Create a polygon from a list of points.
        let polygon = Polygon(points: [
            Point(x: -20e5, y: 20e5),
            Point(x: 20e5, y: 20e5),
            Point(x: 20e5, y: -20e5),
            Point(x: -20e5, y: -20e5)
        ])
        
        // Create a graphic of the polygon and add it to the overlay.
        let polygonGraphic = Graphic(geometry: polygon)
        graphicsOverlay.addGraphic(polygonGraphic)
        
        // Create a renderer using a simple fill symbol.
        let polygonSymbol = SimpleFillSymbol(style: .solid, color: .yellow)
        graphicsOverlay.renderer = SimpleRenderer(symbol: polygonSymbol)
        
        return graphicsOverlay
    }()
    
    /// A Boolean value indicating whether the graphic alert is showing.
    @State private var isShowingGraphicAlert = false
    
    /// The text shown in the graphic alert that shows the alert when changed.
    @State private var graphicAlertText = "" {
        didSet { isShowingGraphicAlert = graphicAlertText.isNotEmpty }
    }
    
    /// A Boolean value indicating whether to show an error alert.
    @State private var isShowingErrorAlert = false
    
    /// The error shown in the error alert.
    @State private var error: Error? {
        didSet { isShowingErrorAlert = error != nil }
    }
    
    var body: some View {
        MapViewReader { mapViewProxy in
            MapView(map: map, graphicsOverlays: [graphicsOverlay])
                .onSingleTapGesture { screenPoint, _ in
                    Task {
                        do {
                            // Identify the screen point on the graphics overlay using the proxy.
                            // Use `identifyGraphicsOverlays` instead if you need to identify on
                            // all the graphics overlay present in the map view.
                            let identifyResult = try await mapViewProxy.identify(
                                on: graphicsOverlay,
                                screenPoint: screenPoint,
                                tolerance: 12
                            )
                            
                            // Display an alert if a graphic was found at the screen point.
                            if identifyResult.graphics.isNotEmpty {
                                let postfix = identifyResult.graphics.count > 1 ? "s" : ""
                                graphicAlertText = "Tapped on \(identifyResult.graphics.count) graphic\(postfix)."
                            }
                        } catch {
                            // Show an error alert for an error throw while identifying.
                            self.error = error
                        }
                    }
                }
                .alert(graphicAlertText, isPresented: $isShowingGraphicAlert) {
                    Button("OK") { }
                }
                .alert(isPresented: $isShowingErrorAlert, presentingError: error)
        }
    }
}

private extension Collection {
    /// A Boolean value indicating whether the collection is not empty.
    var isNotEmpty: Bool {
        !self.isEmpty
    }
}
