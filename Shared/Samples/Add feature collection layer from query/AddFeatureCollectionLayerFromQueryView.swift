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

struct AddFeatureCollectionLayerFromQueryView: View {
    /// A map with an ocean basemap style.
    @State private var map = Map(basemapStyle: .arcGISOceans)
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    var body: some View {
        MapView(map: map)
            .task {
                do {
                    let featureCollection = try await queryFeatures()
                    let layer = FeatureCollectionLayer(featureCollection: featureCollection)
                    map.addOperationalLayer(layer)
                } catch {
                    // Updates the error and shows an alert if any failure occurs.
                    self.error = error
                }
            }
            .errorAlert(presentingError: $error)
    }
    
    /// Queries a service feature table and gets a feature collection.
    /// - Returns: A feature collection containing the queried features.
    private func queryFeatures() async throws -> FeatureCollection {
        // A wildfire service feature table to be queried.
        let featureTable = ServiceFeatureTable(
            url: URL(string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/Wildfire/FeatureServer/0")!
        )
        let parameters = QueryParameters()
        // Sets the where clause to find all the fire origins and spot fires.
        parameters.whereClause = "eventtype=7 OR eventtype=22"
        // Queries the service feature table.
        let queryResults = try await featureTable.queryFeatures(using: parameters)
        let table = FeatureCollectionTable(featureSet: queryResults)
        let featureCollection = FeatureCollection(featureCollectionTables: [table])
        return featureCollection
    }
}
