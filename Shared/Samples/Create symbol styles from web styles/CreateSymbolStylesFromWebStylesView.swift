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

import ArcGIS
import SwiftUI

struct CreateSymbolStylesFromWebStylesView: View {
    /// The display scale of the environment.
    @Environment(\.displayScale) private var displayScale
    
    /// A map with a light gray basemap centered on LA County.
    @State private var map: Map = {
        let map = Map(basemapStyle: .arcGISLightGray)
        map.referenceScale = 1e5
        map.initialViewpoint = Viewpoint(
            latitude: 34.28301,
            longitude: -118.44186,
            scale: 1e4
        )
        return map
    }()
    
    /// A feature layer with the LA County Points of Interest service.
    @State private var featureLayer: FeatureLayer = {
        let featureTable = ServiceFeatureTable(url: .laPointsOfInterest)
        return FeatureLayer(featureTable: featureTable)
    }()
    
    /// The legend items for the different symbols from the selected symbol style.
    @State private var legendItems: [LegendItem] = []
    
    /// A Boolean value indicating whether the legend sheet is showing.
    @State private var isShowingLegend = false
    
    var body: some View {
        MapView(map: map)
            .onScaleChanged { scale in
                // Prevent the symbols from scaling when the map zooms out too far.
                featureLayer.scalesSymbols = scale >= 8e4
            }
            .task(id: displayScale) {
                // Update the symbols when the display scale changes.
                await updateSymbols(displayScale: displayScale)
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button("Legend") {
                        isShowingLegend = true
                    }
                    .sheet(isPresented: $isShowingLegend, detents: [.medium]) {
                        legendList
                    }
                }
            }
    }
    
    /// The legend list that describes what each symbol represents.
    private var legendList: some View {
        NavigationView {
            List(legendItems, id: \.name) { legendItem in
                Label {
                    Text(legendItem.name)
                } icon: {
                    Image(uiImage: legendItem.image)
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
    /// Updates the symbols using the symbol style.
    /// - Parameter scale: The display scale for the swatch images.
    private func updateSymbols(displayScale: CGFloat) async {
        // An Esri 2D point symbol style created from a web style.
        let esri2DPointSymbolStyle = SymbolStyle(
            styleName: "Esri2DPointSymbolsStyle",
            portal: .arcGISOnline(connection: .anonymous)
        )
        
        // Get the symbols and associated information using the symbol style and types.
        let symbolDetails = await getSymbols(
            symbolStyle: esri2DPointSymbolStyle,
            symbolTypes: SymbolType.allCases
        )
        
        // Create the legend list with symbol swatches and related details.
        let legendItems: [LegendItem] = await withTaskGroup(of: LegendItem?.self) { group in
            for detail in symbolDetails {
                group.addTask {
                    // Get the image swatch for the symbol using the display scale.
                    if let swatch = try? await detail.symbol.makeSwatch(scale: displayScale) {
                        return LegendItem(name: detail.name, image: swatch)
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
        
        // Update the legend list items.
        self.legendItems = legendItems.sorted(using: KeyPathComparator(\.name))
        
        // Create unique values and set them to the feature layer's renderer.
        featureLayer.renderer = makeUniqueValueRenderer(fieldNames: ["cat2"], symbolDetails: symbolDetails)
        
        // Add the feature layer with updated symbols to the map.
        map.removeAllOperationalLayers()
        map.addOperationalLayer(featureLayer)
    }
    
    /// Get certain types of symbols from a symbol style.
    /// - Parameters:
    ///   - symbolStyle: A `SymbolStyle` object from a web style.
    ///   - symbolTypes: The types of symbols to get from the symbol style.
    /// - Returns: An `Array` of `SymbolDetail`s which contain a symbol and associated information.
    private func getSymbols(symbolStyle: SymbolStyle, symbolTypes: [SymbolType]) async -> [SymbolDetail] {
        // Get the symbol and details for each symbol type.
        let symbolDetails: [SymbolDetail] = await withTaskGroup(of: [SymbolDetail]?.self) { group in
            for type in symbolTypes {
                group.addTask {
                    // Get the symbol from the symbol style using the symbol's name from the type.
                    async let symbol = symbolStyle.symbol(forKeys: [type.name])
                    if let symbolDetail = try? await [SymbolDetail(
                        name: type.name,
                        categoryNames: type.categoryNames,
                        symbol: symbol
                    )] {
                        return symbolDetail
                    } else {
                        return nil
                    }
                }
            }
            
            var details: [SymbolDetail] = []
            for await detail in group where detail != nil {
                details.append(contentsOf: detail!)
            }
            return details
        }
        return symbolDetails
    }
    
    /// Creates a `UniqueValueRenderer` used to render a feature layer with symbol styles.
    /// - Parameters:
    ///   - fieldNames: The attributes to match the unique values against.
    ///   - symbolDetails: An `Array` of symbols and their associated information.
    /// - Returns: An `UniqueValueRenderer` object with the symbol `UniqueValue`s.
    private func makeUniqueValueRenderer(fieldNames: [String], symbolDetails: [SymbolDetail]) -> UniqueValueRenderer {
        let uniqueValues = symbolDetails.flatMap { detail in
            // Create a unique value for each category value of symbol so the
            // field name matches to all category values.
            detail.categoryNames.map { value in
                UniqueValue(description: "", label: detail.name, symbol: detail.symbol, values: [value])
            }
        }
        return UniqueValueRenderer(fieldNames: fieldNames, uniqueValues: uniqueValues)
    }
    
    /// A struct containing a symbol and its associated information.
    private struct SymbolDetail {
        /// The name of the symbol in the web style.
        let name: String
        /// The category names of features represented by the symbol.
        let categoryNames: [String]
        /// The symbol from the symbol style.
        let symbol: Symbol
    }
    
    /// A struct for displaying legend info in a list row.
    private struct LegendItem {
        /// The description label of the legend item.
        let name: String
        /// The image swatch of the legend item.
        let image: UIImage
    }
    
    /// The types of symbols to get from the symbol style .
    private enum SymbolType: CaseIterable, Comparable {
        case atm, beach, campground, cityHall, hospital, library, park, placeOfWorship, policeStation, postOffice, school, trail
        
        /// The names of the symbols in the web style.
        var name: String {
            switch self {
            case .atm:
                return "atm"
            case .beach:
                return "beach"
            case .campground:
                return "campground"
            case .cityHall:
                return "city-hall"
            case .hospital:
                return "hospital"
            case .library:
                return "library"
            case .park:
                return "park"
            case .placeOfWorship:
                return "place-of-worship"
            case .policeStation:
                return "police-station"
            case .postOffice:
                return "post-office"
            case .school:
                return "school"
            case .trail:
                return "trail"
            }
        }
        
        /// The category names of features represented by a type of symbol.
        var categoryNames: [String] {
            switch self {
            case .atm:
                return ["Banking and Finance"]
            case .beach:
                return ["Beaches and Marinas"]
            case .campground:
                return ["Campgrounds"]
            case .cityHall:
                return ["City Halls", "Government Offices"]
            case .hospital:
                return ["Hospitals and Medical Centers", "Health Screening and Testing", "Health Centers", "Mental Health Centers"]
            case .library:
                return ["Libraries"]
            case .park:
                return ["Parks and Gardens"]
            case .placeOfWorship:
                return ["Churches"]
            case .policeStation:
                return ["Sheriff and Police Stations"]
            case .postOffice:
                return ["DHL Locations", "Federal Express Locations"]
            case .school:
                return ["Public High Schools", "Public Elementary Schools", "Private and Charter Schools"]
            case .trail:
                return ["Trails"]
            }
        }
    }
}

private extension URL {
    /// LA County Points of Interest service URL used to create a feature layer.
    static var laPointsOfInterest: URL {
        URL(string: "http://services.arcgis.com/V6ZHFr6zdgNZuVG0/arcgis/rest/services/LA_County_Points_of_Interest/FeatureServer/0")!
    }
}

#Preview {
    NavigationView {
        CreateSymbolStylesFromWebStylesView()
    }
}
