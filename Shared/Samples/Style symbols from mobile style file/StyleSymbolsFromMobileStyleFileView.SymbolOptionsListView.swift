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
        
        var body: some View {
            VStack {
                Image(uiImage: model.currentSymbol?.image ?? UIImage())
                
                List {
                    // Create a picker for each symbol category.
                    ForEach(SymbolCategory.allCases, id: \.self) { category in
                        Section(category.label) {
                            Picker("Symbol Names", selection: $model.symbolOptionSelections.categoryKeys[category]) {
                                ForEach(model.symbolsList.filter { $0.category == category.rawValue }, id: \.key) { symbol in
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
                await model.updateCurrentSymbol()
            }
            .task(id: displayScale) {
                // Update all the symbols when the display scale changes.
                await model.updateDisplayScale(using: displayScale)
            }
            .errorAlert(presentingError: $model.error)
        }
    }
}
