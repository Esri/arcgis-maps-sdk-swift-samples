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
    /// All samples retrieved from the Samples directory.
    let samples: [Sample]
    
    /// A Boolean value indicating whether the add favorite sheet is showing.
    @State private var isShowingSheet = false
    
    /// The names of the favorited samples loaded from user defaults.
    @AppStorage(UserDefaults.favoritedSamplesKey) private var favoritedNames: [String] = []
    
    /// A list of the favorited samples.
    private var favoritedSamples: [Sample] {
        favoritedNames.compactMap { name in
            samples.first(where: { $0.name == name })
        }
    }
    
    var body: some View {
        List {
            ForEach(favoritedSamples, id: \.name) { sample in
                SampleLink(sample)
            }
            .onMove { fromOffsets, toOffset in
                favoritedNames.move(fromOffsets: fromOffsets, toOffset: toOffset)
            }
            .onDelete { atOffsets in
                favoritedNames.remove(atOffsets: atOffsets)
            }
        }
        .listStyle(.sidebar)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                EditButton()
                
                Button {
                    isShowingSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .sheet(isPresented: $isShowingSheet) {
                    AddFavoriteView(samples: samples)
                }
            }
        }
    }
}

private extension FavoritesView {
    /// A view to add a favorite sample from a searchable list.
    struct AddFavoriteView: View {
        /// All samples retrieved from the Samples directory.
        let samples: [Sample]
        
        /// The action to dismiss the sheet.
        @Environment(\.dismiss) private var dismiss: DismissAction
        
        /// The names of the favorited samples loaded from user defaults.
        @AppStorage(UserDefaults.favoritedSamplesKey) private var favoritedNames: [String] = []
        
        /// The search query in the search bar.
        @State private var query = ""
        
        /// The samples displayed in the search list.
        var displayedSamples: [Sample] {
            if query.isEmpty {
                return samples
            } else {
                return samples.filter { $0.name.contains(query) }
            }
        }
        
        var body: some View {
            NavigationView {
                List {
                    ForEach(displayedSamples, id: \.name) { sample in
                        Button {
                            if !favoritedNames.contains(sample.name) {
                                favoritedNames.append(sample.name)
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
                    ToolbarItem(placement: .navigationBarTrailing) {
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

// MARK: User Defaults

extension UserDefaults {
    /// The key to read and write favorited sample names to the user defaults.
    static var favoritedSamplesKey: String {
        "favoritedSamples"
    }
}

/// An extension allowing an array to be used with the app storage property wrapper.
extension Array: RawRepresentable where Element == String {
    /// Creates a new array from a given raw value.
    /// - Parameter rawValue: The raw value of the array to create.
    public init(rawValue: String) {
        if let data = rawValue.data(using: .utf8),
           let result = try? JSONDecoder().decode([Element].self, from: data) {
            self = result
        } else {
            self = []
        }
    }
    
    /// The raw value of the array.
    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let result = String(data: data, encoding: .utf8)
        else { return "[]" }
        return result
    }
}
