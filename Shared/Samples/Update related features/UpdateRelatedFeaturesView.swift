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

struct UpdateRelatedFeaturesView: View {
    var map = Map(basemapStyle: .arcGISTopographic)
    
    var body: some View {
        MapView(map: map)
            .task {
                let geodatabase = ServiceGeodatabase(url: .alaskaParksFeatureService)
                do {
                    try await geodatabase.load()
                    let table1 = geodatabase.table(withLayerID: 0)
                    let table2 = geodatabase.table(withLayerID: 1)
                } catch {
                    print(error)
                }
            }
    }
}

extension URL {
    static var alaskaParksFeatureService: URL {
        URL(string:" https://services2.arcgis.com/ZQgQTuoyBrtmoGdP/ArcGIS/rest/services/AlaskaNationalParksPreserves_Update/FeatureServer")!
    }
}
