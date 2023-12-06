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
    /// All samples retrieved from the Samples directory.
    private let samples: [Sample]
    
    /// The sample categories generated from the samples list.
    private let categories: [String]
    
    init(samples: [Sample]) {
        self.samples = samples
        categories = Set(samples.map(\.category)).sorted()
    }
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(), GridItem()]) {
                CategoryTile(name: "Favorites") {
                    FavoritesView(samples: samples)
                }
                
                ForEach(categories, id: \.self) { category in
                    CategoryTile(name: category) {
                        List {
                            ForEach(samples.filter { $0.category == category }, id: \.name) { sample in
                                SampleLink(sample)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
}

private extension CategoriesView {
    struct CategoryTile<Content: View>: View {
        /// The name of the category.
        let name: String
        
        /// The destination view for the category tile to present.
        @ViewBuilder let destination: Content
        
        var body: some View {
            NavigationLink {
                destination
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
