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

import SwiftUI

struct CategoryView: View {
    /// A Boolean value that indicates whether the user is searching.
    @Environment(\.isSearching) private var isSearching
    
    /// All samples retrieved from the Samples directory.
    let samples: [Sample]
    
    /// The search query in the search bar.
    @Binding private(set) var query: String
    
    /// The samples to display in the name section of the search list.
    @State private var nameSearchResults: [Sample] = []
    
    /// The samples to display in the description section of the search list.
    @State private var descriptionSearchResults: [Sample] = []
    
    /// The samples to display in the tags section of the search list.
    @State private var tagsSearchResults: [Sample] = []
    
    /// A Boolean value that indicates whether to present the about view.
    @State private var isAboutViewPresented = false
    
    var body: some View {
        Group {
            if !isSearching {
                CategoryGridView(samples: samples)
            } else {
                // The search results list.
                List {
                    if !nameSearchResults.isEmpty {
                        Section(header: Text("Name Results")) {
                            SampleListView(samples: nameSearchResults, query: query)
                        }
                    }
                    if !descriptionSearchResults.isEmpty {
                        Section(header: Text("Description Results")) {
                            SampleListView(samples: descriptionSearchResults, query: query)
                        }
                    }
                    if !tagsSearchResults.isEmpty {
                        Section(header: Text("Tag Results")) {
                            SampleListView(samples: tagsSearchResults, query: query)
                        }
                    }
                }
                .onChange(of: query) { _ in
                    searchSamples(in: samples, with: query)
                }
                .onAppear {
                    searchSamples(in: samples, with: query)
                }
            }
        }
        .navigationTitle("Samples")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    isAboutViewPresented = true
                } label: {
                    Image(systemName: "info.circle")
                }
                .sheet(isPresented: $isAboutViewPresented) {
                    AboutView()
                }
            }
        }
    }
    
    /// Searches through a list of samples to find ones that match the query.
    /// - Parameters:
    ///   - samples: The `Array` of samples to search through.
    ///   - query: The `String` to search with.
    private func searchSamples(in samples: [Sample], with query: String) {
        // Show all samples in the name section when query is empty.
        guard !query.isEmpty else {
            nameSearchResults = samples
            return
        }
        
        // The names of the samples already found in a previous section.
        var previousSearchResults: Set<String> = []
        
        // Update the name section results.
        nameSearchResults = searchNames(in: samples, with: query)
        previousSearchResults.formUnion(nameSearchResults.map(\.name))
        
        // Update the description section results.
        descriptionSearchResults = searchDescriptions(in: samples, with: query)
            .filter { !previousSearchResults.contains($0.name) }
        previousSearchResults.formUnion(descriptionSearchResults.map(\.name))
        
        // Update the tags section results.
        tagsSearchResults = searchTags(in: samples, with: query)
            .filter { !previousSearchResults.contains($0.name) }
    }
}
