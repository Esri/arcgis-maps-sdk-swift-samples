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

struct ManageFeaturesView: View {
    /// A map with a streets basemap and a feature layer.
    @State private var model = Model()
    
    var body: some View {
        VStack {
            switch model.data {
            case .success(let data):
                MapView(map: data.map)
            case .failure:
                ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text("Failed to load sample data."))
            case .none:
                ProgressView()
            }
        }
        .task { await model.loadData() }
    }
}

extension ManageFeaturesView {
    struct Data {
        let map: Map
        let geodatabase: ServiceGeodatabase
        let featureTable: ServiceFeatureTable
    }
}

extension ManageFeaturesView {
    @Observable
    @MainActor
    final class Model {
        var data: Result<Data, Error>?
        
        func loadData() async {
            let map = Map(basemapStyle: .arcGISStreets)
            map.initialViewpoint = Viewpoint(
                center: Point(x: -10_800_000, y: 4_500_000, spatialReference: .webMercator),
                scale: 3e7
            )
            
            let geodatabase = ServiceGeodatabase(
                url: URL(string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/DamageAssessment/FeatureServer/0")!
            )
            
            do {
                try await geodatabase.load()
                let featureTable = geodatabase.table(withLayerID: 0)!
                let layer = FeatureLayer(featureTable: featureTable)
                map.addOperationalLayer(layer)
                data = .success(
                    Data(map: map, geodatabase: geodatabase, featureTable: featureTable)
                )
            } catch {
                data = .failure(error)
            }
        }
    }
}

#Preview {
    ManageFeaturesView()
}
