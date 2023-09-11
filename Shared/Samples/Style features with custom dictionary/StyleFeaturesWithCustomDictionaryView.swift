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
    /// A map with a topographic basemap and centered on Esri in Redlands, CA.
    @State private var map: Map = {
        let map = Map(basemapStyle: .arcGISTopographic)
        map.initialViewpoint = Viewpoint(
            latitude: 34.0543,
            longitude: -117.1963,
            scale: 1e4
        )
        return map
    }()
    
    /// A feature layer with restaurants in Redlands, CA.
    @State private var featureLayer: FeatureLayer = {
        let restaurantFeatureTable = ServiceFeatureTable(url: .redlandsRestaurants)
        return FeatureLayer(featureTable: restaurantFeatureTable)
    }()
    
    /// A dictionary renderer created from a custom symbol style hosted on ArcGIS Online.
    let dictionaryRendererFromWebStyle: DictionaryRenderer = {
        // The restaurant web style.
        let item = PortalItem(
            portal: .arcGISOnline(connection: .anonymous),
            id: .restaurantWebStyle
        )
        
        // Create the dictionary renderer from the web style.
        let restaurantStyle = DictionarySymbolStyle(portalItem: item)
        
        // Map the input fields in the feature layer to the dictionary symbol
        // style's expected fields for symbols.
        return DictionaryRenderer(
            dictionarySymbolStyle: restaurantStyle,
            symbologyFieldOverrides: ["healthgrade": "Inspection"],
            textFieldOverrides: [:]
        )
    }()
    
    /// The current dictionary style.
    @State private var dictionaryStyle: DictionaryStyle = .web
    
    init() {
        featureLayer.renderer = dictionaryRendererFromWebStyle
        map.addOperationalLayer(featureLayer)
    }
    
    var body: some View {
        VStack {
            MapView(map: map)
            
            Picker("Dictionary Symbol Style", selection: $dictionaryStyle) {
                ForEach(DictionaryStyle.allCases, id: \.self) { style in
                    Text(style.label)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            .onChange(of: dictionaryStyle) { _ in
            }
        }
    }
}

private extension StyleFeaturesWithCustomDictionaryView {
    // The custom dictionary styles to choose from.
    enum DictionaryStyle: CaseIterable {
        case web, file
        
        /// A human-readable label for the dictionary style.
        var label: String {
            switch self {
            case .web: return "Web Style"
            case .file: return "Style File"
            }
        }
    }
}

private extension PortalItem.ID {
    /// The portal item ID of a restaurant web style.
    static var restaurantWebStyle: Self { Self("adee951477014ec68d7cf0ea0579c800")! }
}

private extension URL {
    /// Feature service URL with points representing restaurants in Redlands, CA.
    static var redlandsRestaurants: URL {
        URL(string: "https://services2.arcgis.com/ZQgQTuoyBrtmoGdP/arcgis/rest/services/Redlands_Restaurants/FeatureServer/0")!
    }
}
