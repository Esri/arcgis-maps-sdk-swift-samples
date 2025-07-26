// Copyright 2025 Esri
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

struct ShowWFSLayerWithXMLQueryView: View {
    /// The view model for the sample.
    @State private var model = Model()
    /// The error shown in the error alert.
    @State private var error: Error?
    
    var body: some View {
        MapViewReader { mapView in
            MapView(map: model.map)
            // Overlay with loading view in the center if data
            // is currently being loaded.
                .overlay(alignment: .center) {
                    if model.isLoading {
                        loadingView
                    }
                }
                .task {
                    do {
                        // Load the WFS data via the model
                        try await model.loadData()
                        
                        // If the table has a spatial extent and the initial
                        // viewpoint hasn't been set yet
                        if let extent = model.statesTable.extent,
                           !model.hasSetInitialViewpoint {
                            // Mark that the initial viewpoint has been set
                            model.hasSetInitialViewpoint = true
                            // Animate the map to the extent of the data over 2 seconds
                            await mapView.setViewpoint(
                                Viewpoint(boundingGeometry: extent),
                                duration: 2.0
                            )
                        }
                        
                        // Mark that loading has completed.
                        model.isLoading = false
                    } catch {
                        // If an error occurs during loading, capture it to trigger an alert.
                        self.error = error
                    }
                }
            // Display an alert if there is an error during data loading
                .errorAlert(presentingError: $error)
        }
    }
    
    var loadingView: some View {
        ProgressView(
            """
            Loading query
            data
            """
        )
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 10))
        .shadow(radius: 50)
        .multilineTextAlignment(.center)
    }
}

private extension ShowWFSLayerWithXMLQueryView {
    @MainActor
    @Observable
    class Model {
        /// Map with the Topographic basemap style
        var map = Map(basemapStyle: .arcGISTopographic)
        
        /// Flag to track if the initial viewpoint has been set.
        var hasSetInitialViewpoint = false
        
        /// Create a WFS (Web Feature Service) feature table using a specified URL and table name.
        var statesTable = WFSFeatureTable(
            url: .wfsUrl, // The URL to the WFS service
            tableName: .seattleTreesDowntown // The name of the table within the service
        )
        
        /// Flag to indicate whether data is currently being loaded.
        var isLoading = false
        
        /// Asynchronous function to load data from the WFS service
        func loadData() async throws {
            isLoading = true
            // Set the axis order to not swap X and Y (used for coordinate systems.)
            statesTable.axisOrder = .noSwap
            // Use manual cache mode so data must be explicitly loaded from the service.
            statesTable.featureRequestMode = .manualCache
            try await statesTable.load()
            // Create a feature layer from the table and add it to the map.
            let layer = FeatureLayer(featureTable: statesTable)
            map.addOperationalLayer(layer)
            // Populate the feature table with data from the WFS service using an XML query.
            _ = try await statesTable.populateFromService(
                usingXMLRequest: xmlQuery,
                clearCache: true
            )
        }
    }
}

#Preview {
    ShowWFSLayerWithXMLQueryView()
}

extension ShowWFSLayerWithXMLQueryView {
    /// XML query to request features from the WFS service
    /// This specific query fetches only tree features where the "SCIENTIFIC" field equals "Tilia cordata"
    static let xmlQuery = """
        <wfs:GetFeature service="WFS" version="2.0.0" outputFormat="application/gml+xml; version=3.2"
          xmlns:Seattle_Downtown_Features="https://dservices2.arcgis.com/ZQgQTuoyBrtmoGdP/arcgis/services/Seattle_Downtown_Features/WFSServer"
          xmlns:wfs="http://www.opengis.net/wfs/2.0"
          xmlns:fes="http://www.opengis.net/fes/2.0"
          xmlns:gml="http://www.opengis.net/gml/3.2">
          <wfs:Query typeNames="Seattle_Downtown_Features:Trees">
            <fes:Filter>
              <fes:PropertyIsEqualTo>
                <fes:ValueReference>Seattle_Downtown_Features:SCIENTIFIC</fes:ValueReference>
                <fes:Literal>Tilia cordata</fes:Literal>
              </fes:PropertyIsEqualTo>
            </fes:Filter>
          </wfs:Query>
        </wfs:GetFeature>
        """
}

private extension URL {
    /// Static property to return the full URL for the WFS GetCapabilities request
    static var wfsUrl: URL {
        URL(string: "https://dservices2.arcgis.com/ZQgQTuoyBrtmoGdP/arcgis/services/Seattle_Downtown_Features/WFSServer?service=wfs&request=getcapabilities")!
    }
}

extension String {
    /// This string matches the `typeNames` used in the XML query to identify the layer to query.
    static var seattleTreesDowntown: String {
        "Seattle_Downtown_Features:Trees"
    }
}
