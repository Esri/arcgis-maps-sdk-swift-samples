// Copyright 2025 Esri
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

struct SearchSymbolStyleDictionaryView: View {
    /// The error shown in the error alert.
    @State private var error: (any Error)?
    /// The view model for the sample.
    @State private var model = Model()
    /// The search results from the symbol style search.
    @State private var searchResults: [SymbolStyleSearchResult] = []
    
    var body: some View {
        List {
            ForEach(searchResults, id: \.key) { result in
                Section("Key: \(result.key)") {
                    Label {
                        Text(result.name)
                            .lineLimit(1)
                            .textSelection(.enabled)
                    } icon: {
                        AsyncSwatch(searchResult: result)
                    }
                    
                    LabeledContent("Category", value: result.category)
                    
                    NavigationLink {
                        List(result.tags, id: \.self) { tag in
                            Text(tag)
                        }
                        .navigationTitle("Tags")
                    } label: {
                        LabeledContent("Tags") {
                            Text("^[\(result.tags.count) tag](inflect: true)")
                        }
                    }
                    
                    LabeledContent("Symbol Class", value: result.symbolClass)
                }
            }
        }
        .task {
            do {
                try await model.dictionarySymbolStyle.load()
                searchResults = try await model.searchSymbolStyles()
            } catch {
                self.error = error
            }
        }
        .errorAlert(presentingError: $error)
    }
}

private extension SearchSymbolStyleDictionaryView {
    /// The view model for the sample.
    class Model {
        /// A MIL-STD-2525D dictionary symbol style from a file.
        let dictionarySymbolStyle = DictionarySymbolStyle(url: .mil2525dStyleFile)
        /// The parameters used to search for symbol styles.
        private let symbolStyleSearchParameters: SymbolStyleSearchParameters = {
            let parameters = SymbolStyleSearchParameters()
            // Sets the search parameters to find specific symbols. You can
            // specify names, tags, symbol classes, categories, and keys.
            parameters.addName("Maritime Points")
            parameters.addTags(["MAIN", "Point"])
            parameters.addSymbolClass("3")
            parameters.addCategory("Point")
            parameters.addKeys([
                "25210100",
                "25210200",
                "25210400",
                "25210500",
                "25210700",
                "25210900"
            ])
            return parameters
        }()
        
        /// Searches the dictionary symbol style using the baked-in parameters.
        /// - Returns: An array of symbol style search results.
        @MainActor
        func searchSymbolStyles() async throws -> [SymbolStyleSearchResult] {
            try await dictionarySymbolStyle.searchSymbols(using: symbolStyleSearchParameters)
        }
    }
    
    struct AsyncSwatch: View {
        /// The display scale of the environment.
        @Environment(\.displayScale) private var displayScale
        
        /// The search result to create a swatch.
        let searchResult: SymbolStyleSearchResult
        /// The result of creating the swatch image.
        @State private var result: Result<UIImage, any Error>?
        
        var body: some View {
            Group {
                switch result {
                case .none:
                    ProgressView()
                case .failure:
                    Image(systemName: "exclamationmark.triangle")
                case .success(let image):
                    Image(uiImage: image)
                }
            }
            .task {
                result = await Result {
                    try await searchResult.symbol.makeSwatch(scale: displayScale)
                }
            }
        }
    }
}

private extension URL {
    /// The URL to the "Joint Military Symbology MIL-STD-2525D" mobile style file.
    static var mil2525dStyleFile: URL {
        Bundle.main.url(forResource: "mil2525d", withExtension: "stylx")!
    }
}
