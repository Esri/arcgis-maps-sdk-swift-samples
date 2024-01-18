// Copyright 2024 Esri
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

struct SearchForWebMapView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// The text query in the search bar.
    @State private var query = ""
    
    /// A Boolean value indicating whether new results are being loaded.
    @State private var resultsAreLoading = false
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(model.portalItems, id: \.id) { item in
                    NavigationLink {
                        SafeMapView(map: Map(item: item))
                            .navigationTitle(item.title)
                    } label: {
                        PortalItemRowView(item: item)
                    }
                    .buttonStyle(.plain)
                    .task {
                        // Load the next results when the last item is reached.
                        guard item.id == model.portalItems.last?.id else { return }
                        
                        resultsAreLoading = true
                        defer { resultsAreLoading = false }
                        
                        do {
                            try await model.findNextItems()
                        } catch {
                            self.error = error
                        }
                    }
                }
                
                if resultsAreLoading {
                    ProgressView()
                        .padding()
                } else if !query.isEmpty && model.portalItems.isEmpty {
                    VStack {
                        Text("No Results")
                            .font(.headline)
                        Text("Check spelling or try a new search.")
                            .font(.footnote)
                    }
                    .padding()
                }
            }
        }
        .background(Color(.secondarySystemBackground))
        .searchable(
            text: $query,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Web Maps"
        )
        .task(id: query) {
            // Load new results when the query changes.
            resultsAreLoading = true
            defer { resultsAreLoading = false }
            
            do {
                try await model.findItems(for: query)
            } catch {
                self.error = error
            }
        }
        .errorAlert(presentingError: $error)
    }
}

#Preview {
    NavigationView {
        SearchForWebMapView()
    }
}
