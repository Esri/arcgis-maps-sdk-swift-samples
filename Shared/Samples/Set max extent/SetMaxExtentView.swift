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

struct SetMaxExtentView: View {
    /// The model with graphics overlay use to show the extent envelope
    /// graphic.
    private class Model: ObservableObject {
        let graphicsOverlay: GraphicsOverlay = {
            let graphicsOverlay = GraphicsOverlay()
            let extentEnvelope = Envelope(xMin: -12139393.2109,
                                          yMin: 4438148.7816,
                                          xMax: -11359277.5124,
                                          yMax: 5012444.0468)
            let envelopeSymbol = SimpleLineSymbol(style: .dash,
                                                  color: .red,
                                                  width: 5)
            let envelopeGraphic = Graphic(geometry: extentEnvelope,
                                          symbol: envelopeSymbol)
            
            graphicsOverlay.addGraphic(envelopeGraphic)
            return graphicsOverlay
        }()
    }
    
    /// The view model for the envolpe graphics.
    @StateObject private var graphicsOverlayModel = Model()
    
    /// A map with streets basemap and max extent of Colorado.
    @State private var map: Map = {
        let map = Map(basemapStyle: .arcGISStreets)
        
        /// The envelope that represents the max extent.
        let extentEnvelope = Envelope(xMin: -12139393.2109,
                                      yMin: 4438148.7816,
                                      xMax: -11359277.5124,
                                      yMax: 5012444.0468)
            
        /// Set the map's max extent to an envelope of Colorado's northwest
        /// and southeast corners.
        map.maxExtent = extentEnvelope
        return map
    }()
    
    var body: some View {
        /// Creates a map view to display the map and envolpe graphics.
        MapView(map: map, graphicsOverlays: [graphicsOverlayModel.graphicsOverlay])
    }
}
