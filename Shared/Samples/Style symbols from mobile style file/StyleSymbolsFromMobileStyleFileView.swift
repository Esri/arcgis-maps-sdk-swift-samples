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
    /// The display scale of the environment.
    @Environment(\.displayScale) private var displayScale
    
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// A Boolean value that indicates whether the symbol options sheet is showing.
    @State private var isShowingSymbolOptionsSheet = false
    
    var body: some View {
        MapView(map: model.map, graphicsOverlays: [model.graphicsOverlay])
            .onSingleTapGesture { _, mapPoint in
                // Add the current symbol to map as a graphic at the tap location.
                let symbolGraphic = Graphic(geometry: mapPoint, symbol: model.currentSymbol?.symbol)
                model.graphicsOverlay.addGraphic(symbolGraphic)
            }
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button("Symbol") {
                        isShowingSymbolOptionsSheet = true
                    }
                    .sheet(isPresented: $isShowingSymbolOptionsSheet, detents: [.large]) {
                        symbolOptionsList
                    }
                    
                    Spacer()
                    Button("Clear") {
                        // Clear all graphics from the map.
                        model.graphicsOverlay.removeAllGraphics()
                    }
                }
            }
            .task(id: displayScale) {
                // Update the current symbol when the display scale change.
                await model.updateCurrentSymbol(displayScale: displayScale)
            }
    }
    
    /// The list containing the symbol options.
    private var symbolOptionsList: some View {
        NavigationView {
            SymbolOptionsListView(model: model)
                .navigationTitle("Symbol")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            isShowingSymbolOptionsSheet = false
                        }
                    }
                }
        }
        .navigationViewStyle(.stack)
    }
}

extension StyleSymbolsFromMobileStyleFileView {
    /// The view model for the sample.
    @MainActor
    class Model: ObservableObject {
        /// A map with a topographic basemap.
        let map = Map(basemapStyle: .arcGISTopographic)
        
        /// The graphics overlay for all the symbol graphics on the map.
        let graphicsOverlay = GraphicsOverlay()
        
        /// The emoji mobile symbol style created from a local symbol style file.
        let symbolStyle = SymbolStyle(url: .emojiMobile)
        
        /// The current symbol created from the symbol style based on the option selections.
        @Published var currentSymbol: SymbolDetails?
        
        /// The current symbol option selections used to create the current symbol.
        @Published var symbolOptionSelections = SymbolOptions(
            eyes: "Eyes-crossed",
            hat: "Hat-cowboy",
            mouth: "Mouth-frown",
            color: Color.yellow,
            size: 40
        )
        
        /// Updates the current symbol with a symbol created from the symbol style using the current option selections.
        /// - Parameter displayScale: The display scale of the environment for creating the symbol swatch.
        func updateCurrentSymbol(displayScale: Double) async {
            // Get the keys from the option selections.
            var symbolKeys = ["Face1"]
            symbolKeys.append(contentsOf: symbolOptionSelections.categoryKeys.map { $0.value })
            
            // Get the symbol from symbol style using the keys.
            if let pointSymbol = try? await symbolStyle.symbol(forKeys: symbolKeys) as? MultilayerPointSymbol {
                // Color lock all layers but the first one.
                let layers = pointSymbol.symbolLayers
                for (i, layer) in layers.enumerated() {
                    layer.colorIsLocked = i != 0 ? true : false
                }
                
                pointSymbol.color = UIColor(symbolOptionSelections.color)
                pointSymbol.size = symbolOptionSelections.size
                
                // Create an image swatch for the symbol using the display scale.
                if let swatch = try? await pointSymbol.makeSwatch(scale: displayScale) {
                    // Update the current symbol with the created symbol and swatch.
                    currentSymbol = SymbolDetails(symbol: pointSymbol, image: swatch)
                }
            }
        }
    }
    
    /// A symbol and its associated information.
    struct SymbolDetails {
        /// The symbol from the symbol style.
        let symbol: Symbol
        /// The image swatch of the symbol.
        let image: UIImage
        /// The name of the symbol as found in the symbol style.
        let name: String
        /// The key of the symbol as found in the symbol style.
        let key: String
        /// The category of the symbol as found in the symbol style.
        let category: String
        /// The human-readable label of the symbol name.
        var label: String {
            let splitName = name.replacingOccurrences(of: "-", with: " ").split(separator: " ")
            return splitName.last?.capitalized ?? name
        }
        
        init(symbol: Symbol, image: UIImage, name: String = "", key: String = "", category: String = "") {
            self.symbol = symbol
            self.image = image
            self.name = name
            self.key = key
            self.category = category
        }
    }
    
    /// The different options used in creating a symbol from the symbol style.
    struct SymbolOptions: Equatable {
        /// A dictionary containing the key of a symbol for each symbol category.
        var categoryKeys: [SymbolCategory: String] = [:]
        /// The color of the symbol.
        var color: Color
        /// The size of the symbol.
        var size: Double
        
        init(eyes: String, hat: String, mouth: String, color: Color, size: Double) {
            categoryKeys[.eyes] = eyes
            categoryKeys[.hat] = hat
            categoryKeys[.mouth] = mouth
            self.color = color
            self.size = size
        }
    }
    
    /// The different symbol categories as found in the symbol style.
    enum SymbolCategory: String, CaseIterable {
        case eyes = "Eyes"
        case hat = "Hat"
        case mouth = "Mouth"
        
        /// A human-readable label of the category name.
        var label: String {
            return self.rawValue.hasSuffix("s") ? self.rawValue : "\(self.rawValue)s"
        }
    }
}

private extension URL {
    /// A URL to the local emoji mobile symbol style file.
    static var emojiMobile: URL {
        Bundle.main.url(forResource: "emoji-mobile", withExtension: "stylx")!
    }
}
