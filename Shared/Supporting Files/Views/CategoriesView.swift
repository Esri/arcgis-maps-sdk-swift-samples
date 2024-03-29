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
    /// All samples that will be shown in the categories.
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
                ForEach(categories, id: \.self) { category in
                    NavigationLink {
                        CategoryList(samples: samples.filter { $0.category == category })
                            .navigationTitle(category)
                    } label: {
                        CategoryTitleView(category: category)
                    }
                    .isDetailLink(false)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    .contentShape(RoundedRectangle(cornerRadius: 30))
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }
}

private extension CategoriesView {
    struct CategoryList: View {
        /// The samples in a category.
        let samples: [Sample]
        
        var body: some View {
            List(samples, id: \.name) { sample in
                NavigationLink {
                    SampleDetailView(sample: sample)
                        .id(sample.name)
                } label: {
                    SampleRow(name: AttributedString(sample.name), description: AttributedString(sample.description))
                }
            }
            .listStyle(.sidebar)
        }
    }
    
    struct CategoryTitleView: View {
        /// The category name used to load the images from assets.
        let category: String
        
        var body: some View {
            Image("\(category.replacingOccurrences(of: " ", with: "-"))-bg")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .overlay {
                    ZStack {
                        Color(red: 0.24, green: 0.24, blue: 0.26, opacity: 0.6)
                        Image("\(category.replacingOccurrences(of: " ", with: "-"))-icon")
                            .resizable()
                            .colorInvert()
                            .padding(10)
                            .frame(width: 50, height: 50)
                            .background(.black.opacity(0.75))
                            .clipShape(Circle())
                        Text(category)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white)
                            .offset(y: 45)
                    }
                }
        }
    }
}
