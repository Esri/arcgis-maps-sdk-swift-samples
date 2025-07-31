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
    /// The error shown in the error alert.
    @State private var error: (any Error)?
    
    /// Map with the Topographic basemap style.
    @State private var map = Map(basemapStyle: .arcGISTopographic)
    
    /// A WFS (Web Feature Service) feature table using a specified URL and table name.
    @State private var seattleTreesTable = WFSFeatureTable(
        url: .wfsUrl,
        tableName: .seattleTreesDowntown
    )
    
    /// A Boolean value indicating whether the XML query is being loaded.
    @State private var isLoading = false
    
    var body: some View {
        MapViewReader { mapView in
            MapView(map: map)
                .overlay(alignment: .center) {
                    if isLoading {
                        loadingView
                    }
                }
                .task {
                    do {
                        // Load the WFS data.
                        try await loadData()
                        if let extent = seattleTreesTable.extent, !isLoading {
                            // Animate the map to the extent of the data over 1 second.
                            await mapView.setViewpoint(
                                Viewpoint(boundingGeometry: extent),
                                duration: 1.0
                            )
                        }
                    } catch {
                        // If an error occurs during loading, capture it to trigger an alert.
                        self.error = error
                    }
                }
                .errorAlert(presentingError: $error)
        }
    }
    
    /// Load data from the WFS service.
    func loadData() async throws {
        isLoading = true
        // Some WFS services return coordinates in (x,y) order, while others use (y,x) order.
        // Set the axis order to not swap x and y.
        seattleTreesTable.axisOrder = .noSwap
        // Use manual cache mode so data must be explicitly loaded from the service.
        seattleTreesTable.featureRequestMode = .manualCache
        // Create a feature layer from the table and add it to the map.
        let layer = FeatureLayer(featureTable: seattleTreesTable)
        map.addOperationalLayer(layer)
        // Populate the feature table with data from the WFS service using an XML query.
        _ = try await seattleTreesTable.populateFromService(
            usingXMLRequest: .xmlQuery,
            clearCache: true
        )
        // Mark that loading has completed.
        isLoading = false
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

#Preview {
    ShowWFSLayerWithXMLQueryView()
}

private extension URL {
    /// A URL for the Seattle Downtown Features WFS GetCapabilities endpoint.
    static var wfsUrl: URL {
        URL(string: "https://dservices2.arcgis.com/ZQgQTuoyBrtmoGdP/arcgis/services/Seattle_Downtown_Features/WFSServer?service=wfs&request=getcapabilities")!
    }
}

extension String {
    /// This string matches the `typeNames` used in the XML query to identify the layer to query.
    static var seattleTreesDowntown: String {
        "Seattle_Downtown_Features:Trees"
    }
    
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
