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

extension StyleSymbolsFromMobileStyleFileView {
    struct SymbolOptionsListView: View {
        /// The display scale of the environment.
        @Environment(\.displayScale) private var displayScale
        
        /// The view model for the sample.
        @ObservedObject var model: Model
        
        /// The list of all the symbols and their associated data from the symbol style.
        @State private var symbols: [SymbolDetails] = []
        
        var body: some View {
            VStack {
                Image(uiImage: model.currentSymbol?.image ?? UIImage())
                
                List {
                    // Create a picker for each symbol category.
                    ForEach(SymbolCategory.allCases, id: \.self) { category in
                        Section(category.label) {
                            Picker("Symbol Names", selection: $model.symbolOptionSelections.categoryKeys[category]) {
                                ForEach(symbols.filter { $0.category == category.rawValue }, id: \.key) { symbol in
                                    Label {
                                        Text(symbol.label)
                                    } icon: {
                                        Image(uiImage: symbol.image)
                                    }
                                    .tag(symbol.key as String?)
                                }
                            }
                            .pickerStyle(.inline)
                            .labelsHidden()
                        }
                    }
                    
                    Section {
                        ColorPicker("Color", selection: $model.symbolOptionSelections.color)
                        VStack {
                            HStack {
                                Text("Size")
                                Spacer()
                                Text(model.symbolOptionSelections.size.formatted(.number.rounded()))
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $model.symbolOptionSelections.size, in: 20...60, step: 1)
                        }
                    }
                }
            }
            .task(id: model.symbolOptionSelections) {
                // Update the current symbol when an option selection changes.
                await model.updateCurrentSymbol(displayScale: displayScale)
            }
            .task(id: displayScale) {
                // Update the symbols when the display scale changes.
                symbols = await symbols(forDisplayScale: displayScale)
                await model.updateCurrentSymbol(displayScale: displayScale)
            }
        }
        
        /// Gets the symbols from the symbol style.
        /// - Parameter displayScale: The display scale of the environment for creating symbol swatches.
        /// - Returns:  An `Array` of `SymbolDetails` which contain a symbol and its associated information.
        private func symbols(forDisplayScale: Double) async -> [SymbolDetails] {
            // Get the default symbol search parameters from the symbol style.
            guard let searchParameters = try? await model.symbolStyle.defaultSearchParameters else { return [] }
            
            // Get the symbol style search results using the search parameters.
            guard let searchResults = try? await model.symbolStyle.searchSymbols(
                using: searchParameters
            ) else { return [] }
            
            // Create a symbol for each search result.
            let symbols = await withTaskGroup(of: SymbolDetails?.self) { group in
                for result in searchResults {
                    group.addTask {
                        // Get the symbol from the symbol style using the symbol's key from the result.
                        if let symbol = try? await self.model.symbolStyle.symbol(forKeys: [result.key]) {
                            // Create an image swatch from the symbol using the display scale.
                            if let swatch = try? await symbol.makeSwatch(scale: displayScale) {
                                return SymbolDetails(
                                    symbol: symbol,
                                    image: swatch,
                                    name: result.name,
                                    key: result.key,
                                    category: result.category
                                )
                            }
                        }
                        return nil
                    }
                }
                
                var symbols: [SymbolDetails] = []
                for await symbol in group {
                    if let symbol {
                        symbols.append(symbol)
                    }
                }
                return symbols.sorted { $0.name < $1.name }
            }
            return symbols
        }
    }
}
