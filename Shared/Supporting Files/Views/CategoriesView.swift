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

struct CategoriesView: View {
    /// The sample categories generated from the samples list.
    private let categories = Set(SamplesApp.samples.map(\.category)).sorted()
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(), GridItem()]) {
                NavigationLink {
                    FavoritesView()
                        .navigationTitle("Favorites")
                } label: {
                    CategoryTile(name: "Favorites")
                }
                .isDetailLink(false)
                .buttonStyle(.plain)
                .contentShape(RoundedRectangle(cornerRadius: 30))
                
                ForEach(categories, id: \.self) { category in
                    NavigationLink {
                        List(SamplesApp.samples.filter { $0.category == category }, id: \.name) { sample in
                            SampleLink(sample)
                        }
                        .listStyle(.sidebar)
                        .navigationTitle(category)
                    } label: {
                        CategoryTile(name: category)
                    }
                    .isDetailLink(false)
                    .buttonStyle(.plain)
                    .contentShape(RoundedRectangle(cornerRadius: 30))
                }
            }
            .padding()
        }
    }
}

private extension CategoriesView {
    struct CategoryTile: View {
        /// The name of the category.
        let name: String
        
        var body: some View {
            Image("\(name.replacingOccurrences(of: " ", with: "-"))-bg")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .overlay {
                    Color(red: 0.24, green: 0.24, blue: 0.26, opacity: 0.6)
                    Image("\(name.replacingOccurrences(of: " ", with: "-"))-icon")
                        .resizable()
                        .colorInvert()
                        .padding(10)
                        .frame(width: 50, height: 50)
                        .background(.black.opacity(0.75))
                        .clipShape(Circle())
                    Text(name)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .offset(y: 45)
                }
                .clipShape(RoundedRectangle(cornerRadius: 15))
        }
    }
}
