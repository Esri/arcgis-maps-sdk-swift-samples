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
        ZStack {
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
                        .onAppear {
                            // Load the next results when the last item is reached.
                            if item.id == model.portalItems.last?.id {
                                model.findNextItems()
                            }
                        }
                    }
                }
                
                ProgressView()
                    .padding()
                    .opacity(resultsAreLoading ? 1 : 0)
            }
            
            VStack {
                Text("No Results")
                    .font(.headline)
                Text("Check spelling or try a new search.")
                    .font(.footnote)
            }
            .opacity(!resultsAreLoading && !query.isEmpty && model.portalItems.isEmpty ? 1 : 0)
        }
        .background(Color(.secondarySystemBackground))
        .searchable(
            text: $query,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search for a web map"
        )
        .onChange(of: query) { _ in
            // Load new results when the query changes.
            model.findItems(for: query)
        }
        .task(id: model.task) {
            guard model.task != nil else { return }
            
            resultsAreLoading = true
            defer { resultsAreLoading = false }
            
            do {
                try await model.task?.value
            } catch {
                self.error = error
            }
        }
        .errorAlert(presentingError: $error)
    }
}

private extension SearchForWebMapView {
    /// A map view that shows an alert and dismisses itself when there is an error loading the map.
    struct SafeMapView: View {
        /// The map to show in the map view.
        let map: Map
        
        /// The action to dismiss the view.
        @Environment(\.dismiss) private var dismiss: DismissAction
        
        /// A Boolean value indicating whether the map is being loaded.
        @State private var mapIsLoading = false
        
        /// The error shown in the error alert.
        @State private var error: Error?
        
        var body: some View {
            ZStack {
                MapView(map: map)
                    .task {
                        mapIsLoading = true
                        defer { mapIsLoading = false }
                        
                        // Show an alert for an error loading the map.
                        do {
                            try await map.load()
                        } catch {
                            self.error = error
                        }
                    }
                    .errorAlert(presentingError: $error)
                    .onChange(of: error == nil) { _ in
                        // Dismiss the view once the error alert is dismissed.
                        guard error == nil else { return }
                        dismiss()
                    }
                
                ProgressView()
                    .opacity(mapIsLoading ? 1 : 0)
            }
        }
    }
    
    /// A view that shows a given portal item's info in a row.
    struct PortalItemRowView: View {
        /// The portal item to display in the row.
        let item: PortalItem
        
        var body: some View {
            VStack {
                HStack {
                    AsyncImage(url: item.thumbnail?.url) { image in
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(height: 75)
                    } placeholder: {
                        Color(.lightGray)
                            .frame(width: 110, height: 75)
                    }
                    .border(.primary)
                    .padding([.leading, .top], 10)
                    
                    Text(item.title)
                    
                    Spacer()
                }
                
                HStack {
                    Text(item.modificationDate?.formatted(
                        Date.FormatStyle(date: .abbreviated, time: .omitted)
                    ) ?? "")
                    .foregroundColor(Color(.systemGray5))
                    
                    Divider()
                        .overlay(.black)
                    
                    Text(item.owner)
                        .foregroundColor(.teal)
                    
                    Spacer()
                }
                .font(.footnote)
                .padding(10)
                .background(Color(.darkGray))
            }
            .background(Color(.systemGray5))
            .border(Color(.darkGray))
            .padding(.top, 8)
            .padding(.horizontal)
            .padding(.horizontal)
        }
    }
}

#Preview {
    NavigationView {
        SearchForWebMapView()
    }
}
