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

struct QueryWithTimeExtentView: View {
    /// A map with an ocean basemap style.
    @State private var map: Map = {
        let map = Map(basemapStyle: .arcGISOceans)
        
        // Sets the initial viewpoint of the map.
        map.initialViewpoint = Viewpoint(latitude: 20.0, longitude: -55.0, scale: 9e7)
        
        return map
    }()
   
    /// A feature table of Atlantic hurricanes.
    let featureTable: ServiceFeatureTable = {
        let featureTable = ServiceFeatureTable(url: .hurricanesService)
        
        // Sets the feature request mode to manual (only manual is currently
        // supported). In this mode, you must manually populate the table -
        // panning and zooming won't request features automatically.
        featureTable.featureRequestMode = .manualCache
        
        return featureTable
    }()
    
    /// The start date of the query's time extent.
    static var startDate: Date {
        Calendar.current.date(from: DateComponents(year: 2000, month: 9, day: 1))!
    }
    
    /// The end date of the query's time extent.
    static var endDate: Date {
        Calendar.current.date(from: DateComponents(year: 2000, month: 9, day: 22))!
    }
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    var body: some View {
        MapView(map: map)
            .task {
                do {
                    let layer = FeatureLayer(featureTable: featureTable)
                    
                    map.addOperationalLayer(layer)
                    
                    try await populateFeatures()
                } catch {
                    self.error = error
                }
            }
    }
    
    /// Populates the feature table using queried features.
    private func populateFeatures() async throws {
        // Creates parameters to query for features within the time extent.
        let queryParameters = QueryParameters()
        let timeExtent = TimeExtent(startDate: Self.startDate, endDate: Self.endDate)
        queryParameters.timeExtent = timeExtent
        
        _ = try await featureTable.populateFromService(
            using: queryParameters,
            clearCache: false,
            outFields: ["*"]
        )
    }
}

private extension URL {
    static let hurricanesService = URL(
        string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/Hurricanes/MapServer/0"
    )!
}

#Preview {
    QueryWithTimeExtentView()
}
