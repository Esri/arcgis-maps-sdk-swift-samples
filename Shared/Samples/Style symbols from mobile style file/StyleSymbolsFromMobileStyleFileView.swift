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

struct StyleSymbolsFromMobileStyleFileView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// A Boolean that indicates whether the symbol sheet is showing.
    @State private var isShowingSymbolSheet = false
    
    var body: some View {
        MapView(map: model.map, graphicsOverlays: [model.graphicsOverlay])
            .onSingleTapGesture { _, mapPoint in
                /// Add current symbol to map on tap.
                let graphic = Graphic(geometry: mapPoint, symbol: model.currentSymbol)
                model.graphicsOverlay.addGraphic(graphic)
            }
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button("Symbol") {
                        isShowingSymbolSheet = true
                    }
                    .sheet(isPresented: $isShowingSymbolSheet, detents: [.large]) {
                        NavigationView {
                            Spacer()
                                .navigationTitle("Layers")
                                .navigationBarTitleDisplayMode(.inline)
                                .toolbar {
                                    ToolbarItem(placement: .confirmationAction) {
                                        Button("Done") {
                                            isShowingSymbolSheet = false
                                        }
                                    }
                                }
                        }
                        .navigationViewStyle(.stack)
                        .frame(idealWidth: 320, idealHeight: 428)
                    }
                    Spacer()
                    Button("Clear") {
                        // Clears all symbol graphics from the map.
                        model.graphicsOverlay.removeAllGraphics()
                    }
                }
            }
    }
}

private extension StyleSymbolsFromMobileStyleFileView {
    /// The view model for the sample.
    class Model: ObservableObject {
        /// A map with a topographic basemap.
        let map = Map(basemapStyle: .arcGISTopographic)
        
        /// The graphics overlay for all the symbol graphics on the map.
        let graphicsOverlay = GraphicsOverlay()
        
        /// The symbols style.
        let symbolStyle = SymbolStyle(name: "emoji-mobile", bundle: nil)
        
        /// The current symbol selection
        var currentSymbol: Symbol
        
        
        init() {
            currentSymbol = SimpleMarkerSymbol(style: .circle, color: .red, size: 10)
        }
    }
}
