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
    /// The editing mode of the environment.
    @Environment(\.editMode) private var editMode
    
    /// A Boolean value indicating whether the add favorite sheet is showing.
    @State private var addFavoriteSheetIsShowing = false
    
    /// The names of the favorite samples loaded from user defaults.
    @AppFavorites private var favoriteNames
    
    /// The favorited samples to show in the list.
    ///
    /// This may contain less elements than `favoriteNames` if the user defaults has invalid values,
    /// such as the name of a sample that was added in another branch.
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
            .onMove(perform: moveFavorites(fromOffsets:toOffset:))
            .onDelete(perform: deleteFavorites(atOffsets:))
        }
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
                        .pagePresentation()
                }
            }
        }
        .onDisappear {
            editMode?.wrappedValue = .inactive
        }
    }
    
    /// Moves favorites in `favoriteNames` using `favoriteSamples` offsets.
    /// - Parameters:
    ///   - source:  The `favoriteSamples` offsets of the favorites to move.
    ///   - destination: The `favoriteSamples` offset of the favorite before which to insert the favorites.
    private func moveFavorites(fromOffsets source: IndexSet, toOffset destination: Int) {
        let favoriteSamples = favoriteSamples
        let newSource = source.reduce(into: IndexSet()) { indexSet, offset in
            let index = favoriteNames.firstIndex(of: favoriteSamples[offset].name)!
            indexSet.insert(index)
        }
        let newDestination = destination < favoriteSamples.count
        ? favoriteNames.firstIndex(of: favoriteSamples[destination].name)!
        : favoriteNames.count
        
        favoriteNames.move(fromOffsets: newSource, toOffset: newDestination)
    }
    
    /// Removes favorites from `favoriteNames` using `favoriteSamples` offsets.
    /// - Parameter offsets: The `favoriteSamples`  offsets of the favorites to remove.
    private func deleteFavorites(atOffsets offsets: IndexSet) {
        let favoriteSamples = favoriteSamples
        let newOffsets = offsets.reduce(into: IndexSet()) { indexSet, offset in
            let index = favoriteNames.firstIndex(of: favoriteSamples[offset].name)!
            indexSet.insert(index)
        }
        
        favoriteNames.remove(atOffsets: newOffsets)
    }
}

private extension FavoritesView {
    /// A view to add a favorite sample from a searchable list.
    struct AddFavoriteView: View {
        /// The action to dismiss the sheet.
        @Environment(\.dismiss) private var dismiss: DismissAction
        
        /// The names of the favorite samples loaded from user defaults.
        @AppFavorites private var favoriteNames
        
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
            NavigationStack {
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
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
            .autocorrectionDisabled()
        }
    }
}
