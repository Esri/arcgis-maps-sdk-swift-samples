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
import ArcGISToolkit

struct QueryFeatureTableView: View {
    @StateObject private var model = Model()
    
    /// A Boolean value indicating whether to show an alert.
    @State private var isShowingAlert = false
    
    /// The error shown in the alert.
    @State private var error: Error? {
        didSet { isShowingAlert = error != nil }
    }
    
    /// The string used to query the feature table.
    @State private var query = ""
    
    /// A Boolean value indicating if the search field has focus.
    @FocusState private var searchFieldIsFocused: Bool
    
    var body: some View {
        MapViewReader { mapViewProxy in
            MapView(map: model.map, viewpoint: .statesViewpoint)
                .alert(isPresented: $isShowingAlert, presentingError: error)
                .overlay(alignment: .topTrailing) {
                    HStack {
                        SearchField(
                            query: $model.currentQuery,
                            prompt: "Search state names",
                            isResultsButtonHidden: true,
                            isResultListHidden: nil
                        )
                        .focused($searchFieldIsFocused)
                        .onSubmit {
                            // Set the query string when the search button is tapped.
                            query = model.currentQuery
                        }
                        .submitLabel(.search)
                        Button("Cancel") {
                            // Hide keyboard.
                            searchFieldIsFocused = false
                        }
                    }
                    .padding()
                }
                .task(id: query) {
                    // Makes sure we have a query string and a layer.
                    guard !query.isEmpty, let featureLayer = model.featureLayer else { return }
                    // Unselect all selected features.
                    featureLayer.unselectFeatures(model.selectedFeatures)
                    model.selectedFeatures.removeAll()
                    // Make the query parameters and execute the query.
                    let queryParameters = QueryParameters()
                    queryParameters.whereClause = "upper(STATE_NAME) LIKE '%\(query.uppercased())%'"
                    do {
                        let queryResult = try await model.featureTable.queryFeatures(using: queryParameters)
                        model.selectedFeatures = Array(queryResult.features())
                        if !model.selectedFeatures.isEmpty {
                            // Display the selection.
                            featureLayer.selectFeatures(model.selectedFeatures)
                            // Zoom to selected feature.
                            if let featureGeometry = model.selectedFeatures.first?.geometry {
                                try await mapViewProxy.setViewpointGeometry(featureGeometry, padding: 25)
                            }
                        } else {
                            // If the query returned no features then zoom
                            // to the extent of the layer.
                            if let layerExtent = featureLayer.fullExtent {
                                try await mapViewProxy.setViewpointGeometry(layerExtent, padding: 50)
                            }
                        }
                    } catch {
                        // Display error as an alert.
                        self.error = error
                    }
                }
        }
    }
}

private extension QueryFeatureTableView {
    class Model: ObservableObject {
        /// A map with a topographic basemap style.
        let map = Map(basemapStyle: .arcGISTopographic)
        
        @Published var currentQuery = ""
        
        var selectedFeatures: [Feature] = []
        
        // Create a feature table using a url.
        let featureTable = ServiceFeatureTable(
             url: URL(string: "https://services.arcgis.com/jIL9msH9OI208GCb/arcgis/rest/services/USA_Daytime_Population_2016/FeatureServer/0")!
        )
        var featureLayer: FeatureLayer?

        init() {
            // Create a feature layer from feature table.
            featureLayer = FeatureLayer(featureTable: featureTable)
            if let featureLayer {
                // Show the layer at all scales.
                featureLayer.minScale = nil
                featureLayer.maxScale = nil
                
                // Set a new renderer.
                let lineSymbol = SimpleLineSymbol(style: .solid, color: .black, width: 1)
                let fillSymbol = SimpleFillSymbol(style: .solid, color: UIColor.yellow.withAlphaComponent(0.5), outline: lineSymbol)
                featureLayer.renderer = SimpleRenderer(symbol: fillSymbol)
                // Add the feature layer to the map.
                map.addOperationalLayer(featureLayer)
            }
        }
    }
}

private extension Viewpoint {
    /// The initial viewpoint.
    static var statesViewpoint: Viewpoint {
        Viewpoint(center: Point(x: -11e6, y: 5e6, spatialReference: .webMercator), scale: 9e7)
    }
}
