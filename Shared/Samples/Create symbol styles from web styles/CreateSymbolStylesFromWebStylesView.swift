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
import ArcGIS

struct CreateSymbolStylesFromWebStylesView: View {
    /// The display scale of this environment.
    @Environment(\.displayScale) private var displayScale
    
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// A Boolean value indicating whether the legends are shown.
    @State private var isShowingLegend = false
    
    var body: some View {
        MapView(map: model.map)
            .task {
                await model.getSymbols(scale: displayScale)
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button("Legend") {
                        isShowingLegend = true
                    }
                    .sheet(isPresented: $isShowingLegend, detents: [.medium]) {
                        symbolStylesList
                    }
                }
            }
    }
    
    ///
    private var symbolStylesList: some View {
        NavigationView {
            List(model.legendItems, id: \.name) { legend in
                Label {
                    Text(legend.name)
                } icon: {
                    Image(uiImage: legend.image)
                }
            }
            .navigationTitle("Symbol Styles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isShowingLegend = false
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .frame(idealWidth: 320, idealHeight: 428)
    }
}

private extension CreateSymbolStylesFromWebStylesView {
    /// The view model for the sample.
    @MainActor
    class Model: ObservableObject {
        /// A map with a light gray basemap.
        var map: Map = {
            let map = Map(basemapStyle: .arcGISLightGray)
            // map.referenceScale = 1e5
            map.initialViewpoint = Viewpoint(
                latitude: 34.28301,
                longitude: -118.44186,
                scale: 1e4
            )
            return map
        }()
        
        /// The Esri 2D point symbol style created from a web style.
        private let symbolStyle = SymbolStyle(styleName: "Esri2DPointSymbolsStyle",
                                              portal: .arcGISOnline(connection: .anonymous)
        )
        
        /// The legends for elements in the utility network.
        @Published private(set) var legendItems: [LegendItem] = []
        
        /// A Boolean value indicating whether to show an alert.
        @Published var isShowingAlert = false
        
        /// The error shown in the alert.
        @Published var error: Error? {
            didSet { isShowingAlert = error != nil }
        }
        
        func getSymbols(scale: CGFloat) async {
            var symbolDetails = [Symbol: (String, [String])]()
            
            // Creates swatches from each symbol.
            let legendItems: [LegendItem] = await withTaskGroup(of: LegendItem?.self) { group in
                for category in SymbolType.allCases {
                    let symbolName = category.symbolName
                    group.addTask {
                        async let symbol = self.symbolStyle.symbol(forKeys: [symbolName])
                        if let swatch = try? await symbol.makeSwatch(scale: scale) {
                            return LegendItem(name: symbolName, image: swatch)
                        } else {
                            return nil
                        }
                    }
                }
                var items: [LegendItem] = []
                for await legendItem in group where legendItem != nil {
                    items.append(legendItem!)
                }
                return items
            }
            
            // Updates the legend items in the model.
            self.legendItems = legendItems.sorted(using: KeyPathComparator(\.name))
        }
    }
}

/// A struct for displaying legend info in a list row.
struct LegendItem {
    /// The description label of the legend item.
    let name: String
    /// The image swatch of the legend item.
    let image: UIImage
}

enum SymbolType: CaseIterable, Comparable {
    case atm, beach, campground, cityHall, hospital, library, park, placeOfWorship, policeStation, postOffice, school, trail
    
    /// The names of the symbols in the web style.
    var symbolName: String {
        let name: String
        switch self {
        case .atm:
            name = "atm"
        case .beach:
            name = "beach"
        case .campground:
            name = "campground"
        case .cityHall:
            name = "city-hall"
        case .hospital:
            name = "hospital"
        case .library:
            name = "library"
        case .park:
            name = "park"
        case .placeOfWorship:
            name = "place-of-worship"
        case .policeStation:
            name = "police-station"
        case .postOffice:
            name = "post-office"
        case .school:
            name = "school"
        case .trail:
            name = "trail"
        }
        return name
    }
    
    /// The category names of features represented by a type of symbol.
    var symbolCategoryValues: [String] {
        let values: [String]
        switch self {
        case .atm:
            values = ["Banking and Finance"]
        case .beach:
            values = ["Beaches and Marinas"]
        case .campground:
            values = ["Campgrounds"]
        case .cityHall:
            values = ["City Halls", "Government Offices"]
        case .hospital:
            values = ["Hospitals and Medical Centers", "Health Screening and Testing", "Health Centers", "Mental Health Centers"]
        case .library:
            values = ["Libraries"]
        case .park:
            values = ["Parks and Gardens"]
        case .placeOfWorship:
            values = ["Churches"]
        case .policeStation:
            values = ["Sheriff and Police Stations"]
        case .postOffice:
            values = ["DHL Locations", "Federal Express Locations"]
        case .school:
            values = ["Public High Schools", "Public Elementary Schools", "Private and Charter Schools"]
        case .trail:
            values = ["Trails"]
        }
        return values
    }
}

