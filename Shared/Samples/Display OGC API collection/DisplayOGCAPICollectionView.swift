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

struct DisplayOGCAPICollectionView: View {
    /// A map with an OGC API collection feature layer.
    @State private var map: Map = {
        let map = Map(basemapStyle: .arcGISTopographic)
        // Sets the viewpoint to Daraa, Syria.
        map.initialViewpoint = Viewpoint(
            latitude: 32.62,
            longitude: 36.10,
            scale: 20_000
        )
        
        // Note: The collection ID can be accessed later via
        // `featureCollectionInfo.collectionID` property of the feature table.
        let table = OGCFeatureCollectionTable(
            url: URL(string: "https://demo.ldproxy.net/daraa")!,
            collectionID: "TransportationGroundCrv"
        )
        // Sets the feature request mode to manual. In this mode, you must
        // manually populate the table - panning and zooming won't request
        // features automatically.
        table.featureRequestMode = .manualCache
        
        let featureLayer = FeatureLayer(featureTable: table)
        let lineSymbol = SimpleLineSymbol(style: .solid, color: .blue, width: 3)
        featureLayer.renderer = SimpleRenderer(symbol: lineSymbol)
        map.addOperationalLayer(featureLayer)
        return map
    }()
    /// The query parameters for the visible extent.
    @State private var visibleExtentQueryParameters: QueryParameters = {
        let queryParameters = QueryParameters()
        queryParameters.spatialRelationship = .intersects
        // Set a limit of 5000 on the number of returned features per request,
        // because the default on some services could be as low as 10.
        queryParameters.maxFeatures = 5_000
        return queryParameters
    }()
    /// A Boolean value indicating whether the map view is navigating.
    @State private var isNavigating = false
    /// The error if the populate operation failed, otherwise `nil`.
    @State private var populateError: Error?
    /// The visible area of the map view.
    @State private var visibleArea: ArcGIS.Polygon?
    /// The OGC feature collection table.
    private var ogcFeatureTable: OGCFeatureCollectionTable {
        (map.operationalLayers.first as! FeatureLayer).featureTable as! OGCFeatureCollectionTable
    }
    
    var body: some View {
        MapView(map: map)
            .onNavigatingChanged { isNavigating = $0 }
            .onVisibleAreaChanged { visibleArea = $0 }
            .task(id: isNavigating) {
                // Populates features when the map stops panning or zooming.
                guard !isNavigating else { return }
                do {
                    // Sets the query's geometry to the current visible extent.
                    visibleExtentQueryParameters.geometry = visibleArea
                    // Populates the feature table with the results of a query.
                    try await ogcFeatureTable.populateFromService(
                        using: visibleExtentQueryParameters,
                        clearCache: false
                    )
                } catch {
                    populateError = error
                }
            }
            .errorAlert(presentingError: $populateError)
    }
}

#Preview {
    DisplayOGCAPICollectionView()
}
