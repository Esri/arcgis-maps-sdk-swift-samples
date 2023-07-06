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
    /// All samples retrieved from the Samples directory.
    let samples: [Sample]
    
    private let categories = [
        CategoryInfo("Analysis"),
        CategoryInfo("Augmented Reality"),
        CategoryInfo("Cloud and Portal"),
        CategoryInfo("Edit and Manage Data"),
        CategoryInfo("Layers"),
        CategoryInfo("Maps"),
        CategoryInfo("Routing and Logistics"),
        CategoryInfo("Scenes"),
        CategoryInfo("Search and Query"),
        CategoryInfo("Utility Networks"),
        CategoryInfo("Visualization")
    ]
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    /// The search query in the search bar.
    @State private var query = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns) {
                    ForEach(categories, id: \.title) { category in
                        NavigationLink {
                            SampleList(
                                samples: samples.filter({ $0.category == category.title }),
                                query: $query
                            )
                                .searchable(text: $query, prompt: "Search By Sample Name")
                        } label: {
                            CategoryTitleView(category: category)
                        }
                    }
                }
                .padding(8)
            }
        }
    }
    
//    var body: some View {
//        if #available(iOS 16, *) {
//            NavigationSplitView {
//                sidebar
//            } detail: {
//                detail
//            }
//        } else {
//            NavigationView {
//                sidebar
//                detail
//            }
//        }
//    }
//
    var sidebar: some View {
        SampleList(samples: samples, query: $query)
            .searchable(text: $query, prompt: "Search By Sample Name")
    }
    
    var detail: some View {
        Text("Select a sample from the list.")
    }
}

private extension CategoryGridView {
    struct CategoryTitleView: View {
        /// The color scheme to detect dark mode.
        @Environment(\.colorScheme) private var colorScheme
        
        ///
        let category: CategoryInfo
        
        var body: some View {
            Image(category.backgroundImage)
                .resizable()
                .overlay {
                    ZStack {
                        Color.secondary
            
                        Circle()
                            .foregroundColor(.primary)
                            .frame(width: 50, height: 50)
                        
                        Image(category.iconImage)
                            .colorInvert(colorScheme == .light)
                        
                        VStack {
                            Spacer()
                            Spacer()
                            Spacer()
                            Text(category.title)
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

private extension CategoryGridView {
    struct CategoryInfo {
        /// The title of the category.
        let title: String
        
        /// The name of the background image in assets for the category.
        var backgroundImage: String {
            "\(title.lowercased().replacingOccurrences(of: " ", with: "-"))-bg"
        }
        
        /// The name of the icon image in assets for the category.
        var iconImage: String {
            "\(title.lowercased().replacingOccurrences(of: " ", with: "-"))-icon"
        }
        
        init(_ title: String) {
            self.title = title
        }
    }
}
    
private extension View {
    @ViewBuilder
    /// Inverts the colors of a view based on a Boolean.
    /// - Parameter inverted: A `Bool` indicating whether to invert colors.
    /// - Returns: A new `View`.
    func colorInvert(_ inverted: Bool) -> some View {
        if inverted {
            self.colorInvert()
        } else {
            self
        }
    }
}
