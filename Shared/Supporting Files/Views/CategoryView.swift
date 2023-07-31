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
                    nameSearchResults = searchSamplesNames()
                    descriptionSearchResults = searchSamplesDescriptions()
                    tagsSearchResults = searchSamplesTags()
                }
                .onAppear {
                    nameSearchResults = searchSamplesNames()
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
}
