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

struct FavoritesView: View {
    /// A Boolean value indicating whether the add favorite sheet is showing.
    @State private var addFavoriteSheetIsShowing = false
    
    /// The names of the favorite samples loaded from user defaults.
    @AppStorage(.favoriteSampleNames) private var favoriteNames: [String] = []
    
    /// A list of the favorite samples.
    private var favoriteSamples: [Sample] {
        favoriteNames.compactMap { name in
            SamplesApp.samples.first(where: { $0.name == name })
        }
    }
    
    var body: some View {
        List {
            ForEach(favoriteSamples, id: \.name) { sample in
                SampleLink(sample)
            }
            .onMove { fromOffsets, toOffset in
                favoriteNames.move(fromOffsets: fromOffsets, toOffset: toOffset)
            }
            .onDelete { atOffsets in
                favoriteNames.remove(atOffsets: atOffsets)
            }
        }
        .listStyle(.sidebar)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                EditButton()
                
                Button {
                    addFavoriteSheetIsShowing = true
                } label: {
                    Image(systemName: "plus")
                }
                .sheet(isPresented: $addFavoriteSheetIsShowing) {
                    AddFavoriteView()
                }
            }
        }
    }
}

private extension FavoritesView {
    /// A view to add a favorite sample from a searchable list.
    struct AddFavoriteView: View {
        /// The action to dismiss the sheet.
        @Environment(\.dismiss) private var dismiss: DismissAction
        
        /// The names of the favorite samples loaded from user defaults.
        @AppStorage(.favoriteSampleNames) private var favoriteNames: [String] = []
        
        /// The search query in the search bar.
        @State private var query = ""
        
        /// The list of samples filtered by the search query.
        private var filteredSamples: [Sample] {
            query.isEmpty
            ? SamplesApp.samples
            : SamplesApp.samples.filter {
                $0.name.localizedStandardContains(query)
            }
        }
        
        var body: some View {
            NavigationView {
                List {
                    ForEach(filteredSamples, id: \.name) { sample in
                        Button {
                            if !favoriteNames.contains(sample.name) {
                                favoriteNames.append(sample.name)
                            }
                            dismiss()
                        } label: {
                            HStack {
                                Text(sample.name)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.inset)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("Choose a sample to add to Favorites")
                            .font(.subheadline)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
        }
    }
}
