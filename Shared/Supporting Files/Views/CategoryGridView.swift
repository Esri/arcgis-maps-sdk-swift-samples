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

struct CategoryGridView: View {
    /// All samples that will be shown in the categories.
    let samples: [Sample]
    
    /// The different sample categories.
    private let categories = [
        "Analysis",
        "Augmented Reality",
        "Cloud and Portal",
        "Edit and Manage Data",
        "Layers",
        "Maps",
        "Routing and Logistics",
        "Scenes",
        "Search and Query",
        "Utility Networks",
        "Visualization"
    ]
    
    /// The columns for the grid.
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns) {
                ForEach(categories, id: \.self) { category in
                    NavigationLink {
                        SampleListView(samples: samples.filter { $0.category == category })
                            .navigationTitle(category)
                    } label: {
                        CategoryTitleView(category: category)
                    }
                }
            }
            .padding(8)
        }
    }
}

private extension CategoryGridView {
    struct CategoryTitleView: View {
        /// The color scheme to detect dark mode.
        @Environment(\.colorScheme) private var colorScheme
        
        /// The category name used to load the images from assets.
        let category: String
        
        var body: some View {
            Image("\(category.replacingOccurrences(of: " ", with: "-"))-bg")
                .resizable()
                .overlay {
                    ZStack {
                        Color.secondary
                        Circle()
                            .foregroundColor(.primary)
                            .frame(width: 50, height: 50)
                        Image("\(category.replacingOccurrences(of: " ", with: "-"))-icon")
                            .colorInvert(colorScheme == .light)
                        VStack {
                            Spacer()
                            Spacer()
                            Spacer()
                            Text(category)
                                .foregroundColor(colorScheme == .dark ? .black : .white)
                                .frame(maxWidth: .infinity)
                            Spacer()
                        }
                    }
                }
                .cornerRadius(15)
        }
    }
}

private extension View {
    @ViewBuilder
    /// Inverts the colors of a view based on a Boolean.
    /// - Parameter inverted: A `Bool` that indicates whether to invert the colors.
    /// - Returns: A new `View`.
    func colorInvert(_ inverted: Bool) -> some View {
        if inverted {
            self.colorInvert()
        } else {
            self
        }
    }
}
