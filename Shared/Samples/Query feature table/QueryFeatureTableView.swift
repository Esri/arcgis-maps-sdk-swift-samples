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

struct QueryFeatureTableView: View {
    @StateObject private var model = Model()
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    /// The text in the search bar.
    @State private var searchBarText = ""
    
    var body: some View {
        MapViewReader { mapViewProxy in
            MapView(map: model.map)
                .errorAlert(presentingError: $error)
                // Makes the search bar.
                .searchable(text: $searchBarText, prompt: Text("Search state names"))
                .onSubmit(of: .search) {
                    model.currentQuery = searchBarText
                }
                // A task that runs when the query text changes.
                .task(id: model.currentQuery) {
                    // Makes sure we have a query string.
                    guard !model.currentQuery.isEmpty else { return }
                    // Unselects all selected features.
                    model.featureLayer.clearSelection()
                    // Makes the query parameters and executes the query.
                    let queryParameters = QueryParameters()
                    queryParameters.whereClause = "upper(STATE_NAME) LIKE '%\(model.currentQuery.uppercased())%'"
                    do {
                        let queryResult = try await model.featureTable.queryFeatures(using: queryParameters)
                        let queryResultFeatures = Array(queryResult.features())
                        if !queryResultFeatures.isEmpty {
                            // Displays the selection.
                            model.featureLayer.selectFeatures(queryResultFeatures)
                            // Zooms to the selected features.
                            if let combinedExtent = GeometryEngine.combineExtents(of: queryResultFeatures.compactMap(\.geometry)) {
                                await mapViewProxy.setViewpointGeometry(combinedExtent, padding: 25)
                            }
                        } else {
                            // If the query returned no features then zooms
                            // to the extent of the layer.
                            if let layerExtent = model.featureLayer.fullExtent {
                                await mapViewProxy.setViewpointGeometry(layerExtent, padding: 50)
                            }
                        }
                    } catch {
                        // Displays the error as an alert.
                        self.error = error
                    }
                }
        }
    }
}

private extension QueryFeatureTableView {
    class Model: ObservableObject {
        /// A map with a topographic basemap style.
        let map: Map = {
            let map = Map(basemapStyle: .arcGISTopographic)
            map.initialViewpoint = Viewpoint(
                center: Point(x: -11e6, y: 5e6, spatialReference: .webMercator),
                scale: 9e7
            )
            return map
        }()

        /// The text used in the query.
        @Published var currentQuery = ""
        
        /// A feature table of US Daytime Population Census Tracts.
        let featureTable = ServiceFeatureTable(
            item: PortalItem(
                portal: .arcGISOnline(connection: .anonymous),
                id: .daytimePopulation
            )
        )

        /// A feature layer created from the service feature table.
        let featureLayer: FeatureLayer
        
        init() {
            // Creates a feature layer from feature table.
            featureLayer = FeatureLayer(featureTable: featureTable)
            // Shows the layer at all scales.
            featureLayer.minScale = nil
            featureLayer.maxScale = nil
            
            // Sets a new renderer on the feature layer.
            let lineSymbol = SimpleLineSymbol(style: .solid, color: .black, width: 1)
            let fillSymbol = SimpleFillSymbol(style: .solid, color: .yellow.withAlphaComponent(0.5), outline: lineSymbol)
            featureLayer.renderer = SimpleRenderer(symbol: fillSymbol)
            // Adds the feature layer to the map.
            map.addOperationalLayer(featureLayer)
        }
    }
}

private extension PortalItem.ID {
    /// The portal item ID of a USA 2016 Daytime Population feature layer.
    static var daytimePopulation: Self { Self("f01f0eda766344e29f42031e7bfb7d04")! }
}

#Preview {
    NavigationView {
        QueryFeatureTableView()
    }
}
