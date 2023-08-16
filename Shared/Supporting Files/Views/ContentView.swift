// Copyright 2022 Esri
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

struct ContentView: View {
    /// All samples retrieved from the Samples directory.
    let samples: [Sample]
    
    /// The search query in the search bar.
    @State private var query = ""
    
    /// Available tokens.
    @State private var tokens: [SearchInput.SampleToken] = []
    
    /// The search scope of the samples.
    @State private var scope = SearchInput.SampleScope.name
    
    var body: some View {
            NavigationSplitView {
                NavigationStack {
                    sidebar
                }
            } detail: {
                detail
            }
            .searchable(text: $query, tokens: $tokens) { token in
                Text(token.label)
            }
            .searchScopes($scope) {
                Text("Name").tag(SearchInput.SampleScope.name)
                Text("Description").tag(SearchInput.SampleScope.description)
                Text("Tags").tag(SearchInput.SampleScope.tags)
            }
            .onChange(of: query) { newValue in
                if let token = SearchInput.SampleToken(rawValue: newValue.lowercased()) {
                    tokens.append(token)
                    query.removeAll(keepingCapacity: true)
                }
            }
    }
    
    var sidebar: some View {
        Sidebar(
            samples: samples,
            searchInput: SearchInput(
                query: query.trimmingCharacters(in: .whitespaces),
                tokens: Set(tokens),
                scope: scope
            )
        )
    }
    
    var detail: some View {
        Text("Select a category from the list.")
    }
}

struct SearchInput {
    enum SampleScope {
        case name
        case description
        case tags
    }
    
    enum SampleToken: String, Identifiable, Hashable, CaseIterable {
        case map
        case scene
        case toolkit
        case utility
        
        var label: String {
            switch self {
            case .map: return "Map"
            case .scene: return "Scene"
            case .toolkit: return "Toolkit"
            case .utility: return "Utility Network"
            }
        }
        
        var id: Self { self }
    }
    
    /// The search query to highlight.
    let query: String
    
    /// The token passed in to filter by tags.
    let tokens: Set<SampleToken>

    /// The scope of the search.
    let scope: SampleScope
}
