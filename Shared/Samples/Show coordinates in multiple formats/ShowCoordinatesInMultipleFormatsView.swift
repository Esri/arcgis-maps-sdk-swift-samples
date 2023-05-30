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

struct ShowCoordinatesInMultipleFormatsView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    var body: some View {
        // Create a map view to display the map.
        MapView(map: model.map, graphicsOverlays: [model.graphicsOverlay])
            .onSingleTapGesture { _, mapPoint in
                model.tapLocation = mapPoint
            }
    }
}

private extension ShowCoordinatesInMultipleFormatsView {
    // The view model for the sample.
    private class Model: ObservableObject {
        /// A map with an imagery basemap.
        var map = Map(basemapStyle: .arcGISImageryStandard)
        
        /// The GraphicsOverlay for the point graphic.
        var graphicsOverlay = GraphicsOverlay()
        
        /// The yellow cross Graphic for the tap location point.
        let tapLocationGraphic: Graphic = {
            let yellowCrossSymbol = SimpleMarkerSymbol(style: .cross, color: .yellow, size: 20)
            return Graphic(symbol: yellowCrossSymbol)
        }()
        
        /// The tap location point.
        @Published var tapLocation: Point!
        
        init() {
            graphicsOverlay.addGraphic(tapLocationGraphic)
        }
    }
}
