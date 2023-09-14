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

struct StyleFeaturesWithCustomDictionaryView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// The current custom dictionary style selection.
    @State private var dictionaryStyleSelection: CustomDictionaryStyle = .file
    
    var body: some View {
        VStack {
            MapView(map: model.map)
            
            // The picker to toggle between style file and web style.
            Picker("Dictionary Symbol Style", selection: $dictionaryStyleSelection) {
                ForEach(CustomDictionaryStyle.allCases, id: \.self) { style in
                    Text(style.label)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            .onChange(of: dictionaryStyleSelection) { _ in
                // Update the feature layer with the correct dictionary renderer
                // on selection change.
                model.restaurantFeatureLayer.renderer = dictionaryStyleSelection == .web ? model.dictionaryRendererFromWebStyle : model.dictionaryRendererFromStyleFile
            }
        }
    }
}

private extension StyleFeaturesWithCustomDictionaryView {
    /// The view model for the sample.
    class Model: ObservableObject {
        /// A map with a topographic basemap centered on Esri in Redlands, CA.
        let map: Map = {
            let map = Map(basemapStyle: .arcGISTopographic)
            map.initialViewpoint = Viewpoint(
                latitude: 34.0543,
                longitude: -117.1963,
                scale: 1e4
            )
            return map
        }()
        
        /// A feature layer with restaurants in Redlands, CA.
        let restaurantFeatureLayer: FeatureLayer = {
            let restaurantFeatureTable = ServiceFeatureTable(url: .redlandsRestaurants)
            return FeatureLayer(featureTable: restaurantFeatureTable)
        }()
        
        /// A dictionary renderer created from a custom symbol style dictionary file (.stylx) on local disk.
        let dictionaryRendererFromStyleFile: DictionaryRenderer = {
            // Create the dictionary symbol style from the style file URL.
            let restaurantStyle = DictionarySymbolStyle(url: .restaurants)
            
            // Create the dictionary renderer from the dictionary symbol style.
            return DictionaryRenderer(dictionarySymbolStyle: restaurantStyle)
        }()
        
        /// A dictionary renderer created from a custom symbol style hosted on ArcGIS Online.
        let dictionaryRendererFromWebStyle: DictionaryRenderer = {
            // The create a portal item with the id of the online web style.
            let restaurant = PortalItem(
                portal: .arcGISOnline(connection: .anonymous),
                id: .restaurantWebStyle
            )
            
            // Create a dictionary symbol style from the web style portal item.
            let restaurantStyle = DictionarySymbolStyle(portalItem: restaurant)
            
            // Create a dictionary renderer from the dictionary symbol style.
            // Map the input fields in the feature layer to the dictionary symbol
            // style's expected fields for symbols.
            return DictionaryRenderer(
                dictionarySymbolStyle: restaurantStyle,
                symbologyFieldOverrides: ["healthgrade": "Inspection"]
            )
        }()
        
        init() {
            // Add the feature layer with the dictionary renderer to the map.
            restaurantFeatureLayer.renderer = dictionaryRendererFromStyleFile
            map.addOperationalLayer(restaurantFeatureLayer)
        }
    }
    
    /// The custom dictionary symbol styles to choose from.
    private enum CustomDictionaryStyle: CaseIterable {
        case file, web
        
        /// A human-readable label for the custom dictionary style.
        var label: String {
            switch self {
            case .file: return "Style File"
            case .web: return "Web Style"
            }
        }
    }
}

private extension PortalItem.ID {
    /// A portal item ID of a restaurant web style hosted on ArcGIS Online.
    static var restaurantWebStyle: Self { Self("adee951477014ec68d7cf0ea0579c800")! }
}

private extension URL {
    /// A URL to the local restaurant symbol style dictionary file.
    static var restaurants: URL {
        Bundle.main.url(forResource: "Restaurant", withExtension: "stylx")!
    }
}

private extension URL {
    /// A URL to an ArcGIS feature service with points representing restaurants in Redlands, CA.
    static var redlandsRestaurants: URL {
        URL(string: "https://services2.arcgis.com/ZQgQTuoyBrtmoGdP/arcgis/rest/services/Redlands_Restaurants/FeatureServer/0")!
    }
}
