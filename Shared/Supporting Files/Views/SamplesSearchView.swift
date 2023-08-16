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

struct SamplesSearchView: View {
    /// The search input.
    private let searchInput: SearchInput
    
    /// The search result to display in the various sections.
    private let searchResult: SearchResult
    
    var body: some View {
        List {
            switch searchInput.scope {
            case .name:
                ForEach(searchResult.nameMatches, id: \.name) { sample in
                    NavigationLink {
                        SampleDetailView(sample: sample)
                            .id(sample.name)
                    } label: {
                        SampleRow(sample: sample, query: searchInput.query)
                    }
                }
            case .description:
                ForEach(searchResult.descriptionMatches, id: \.name) { sample in
                    NavigationLink {
                        SampleDetailView(sample: sample)
                            .id(sample.name)
                    } label: {
                        SampleRow(sample: sample, query: searchInput.query)
                    }
                }
            case .tags:
                ForEach(searchResult.tagMatches, id: \.name) { sample in
                    NavigationLink {
                        SampleDetailView(sample: sample)
                            .id(sample.name)
                    } label: {
                        SampleRow(sample: sample, query: searchInput.query)
                    }
                }
            }
        }
    }
}

// MARK: Search

extension SamplesSearchView {
    /// Create a sample search view.
    /// - Parameters:
    ///   - samples: All samples retrieved from the Samples directory.
    ///   - query: The search query in the search bar.
    init(samples: [Sample], searchInput: SearchInput) {
        self.searchInput = searchInput
        self.searchResult = Self.searchSamples(in: samples, with: searchInput)
    }
}

private extension SamplesSearchView {
    /// A struct that contains various search results to be displayed in
    /// different sections in a list.
    struct SearchResult {
        /// The samples which name partially matches the search query.
        let nameMatches: [Sample]
        /// The samples which description partially matches the search query.
        let descriptionMatches: [Sample]
        /// The samples which one of the tags matches the search query.
        let tagMatches: [Sample]
        
        /// A Boolean value indicating whether all the matches are empty.
        var isEmpty: Bool {
            nameMatches.isEmpty && descriptionMatches.isEmpty && tagMatches.isEmpty
        }
    }
    
    /// Searches through a list of samples to find ones that match the query.
    /// - Parameters:
    ///   - samples: The samples to search through.
    ///   - query: The query to search with.
    private static func searchSamples(in samples: [Sample], with input: SearchInput) -> SearchResult {
        var nameMatches: [Sample] = []
        var descriptionMatches: [Sample] = []
        var tagMatches: [Sample] = []
        
        if input.query.isEmpty && input.tokens.isEmpty {
            // Show all samples in the name section when query is empty.
            nameMatches = samples
        } else {
            var samplesToFilter = samples
            if !input.tokens.isEmpty {
                samplesToFilter = samplesToFilter.filter { sample in
                    Set(sample.tags.map { $0.lowercased() })
                        .isSuperset(of: input.tokens.map { $0.label.lowercased() })
                }
//                    .filter { sample in
//                        sample.tags.contains { tag in
//                            for token in input.tokens {
//                                if tag.localizedCaseInsensitiveCompare(token.label) == .orderedSame {
//                                    return true
//                                }
//                            }
//                            return false
//                        }
//                    }
            }
            if !input.query.isEmpty {
                switch input.scope {
                case .name:
                    // Partially match a query to a sample's name.
                    nameMatches = samplesToFilter
                        .filter { $0.name.localizedCaseInsensitiveContains(input.query) }
                case .description:
                    // Partially match a query to a sample's description.
                    descriptionMatches = samplesToFilter
                        .filter { $0.description.localizedCaseInsensitiveContains(input.query) }
                case .tags:
                    // Match a query to one of the sample's tags.
                    tagMatches = samplesToFilter
                        .filter { sample in
                            sample.tags.contains { tag in
                                tag.localizedCaseInsensitiveCompare(input.query) == .orderedSame
                            }
                        }
                }
            } else {
                nameMatches = samplesToFilter
                descriptionMatches = samplesToFilter
                tagMatches = samplesToFilter
            }
        }
        
        return SearchResult(
            nameMatches: nameMatches,
            descriptionMatches: descriptionMatches,
            tagMatches: tagMatches
        )
    }
}
