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

struct CategoryGridView: View {
    /// The names of the favorited samples loaded from user defaults.
    @AppStorage(UserDefaults.favoriteSamplesKey) var favorites: [String] = []
    
    /// All the samples that will be shown in the categories.
    private let samples: [Sample]
    
    /// The different sample categories generated from the samples list.
    private let categories: [String]
    
    /// The columns for the grid.
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    init(samples: [Sample]) {
        self.samples = samples
        let categoriesSet = Set(samples.map(\.category))
        categories = categoriesSet.sorted()
    }
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns) {
                CategoryTileView(
                    samples: samples.filter { favorites.contains($0.name) },
                    name: "Favorites"
                )
                
                ForEach(categories, id: \.self) { category in
                    CategoryTileView(
                        samples: samples.filter { $0.category == category },
                        name: category
                    )
                }
            }
            .padding(8)
        }
    }
}

private extension CategoryGridView {
    struct CategoryTileView: View {
        /// The samples shown in the category list.
        let samples: [Sample]
        
        /// The category name used to load the images from assets.
        let name: String
        
        var body: some View {
            NavigationLink {
                SampleListView(samples: samples)
                    .navigationTitle(name)
            } label: {
                Image("\(name.replacingOccurrences(of: " ", with: "-"))-bg")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .overlay {
                        ZStack {
                            Color(red: 0.24, green: 0.24, blue: 0.26, opacity: 0.6)
                            Circle()
                                .foregroundColor(.black.opacity(0.75))
                                .frame(width: 50, height: 50)
                            Image("\(name.replacingOccurrences(of: " ", with: "-"))-icon")
                                .colorInvert()
                            Text(name)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.white)
                                .offset(y: 45)
                        }
                    }
            }
            .isDetailLink(false)
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .contentShape(RoundedRectangle(cornerRadius: 30))
            .buttonStyle(.plain)
        }
    }
}
