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
    @State private var map = Map(basemapStyle: .arcGISTopographic)
    @State private var error: Error?
    
    var body: some View {
        MapViewReader { mapView in
            MapView(map: map)
                .task {
                    let geodatabase = ServiceGeodatabase(url: .alaskaParksFeatureService)
                    do {
                        try await geodatabase.load()
                        let preservesTable = geodatabase.table(withLayerID: 0)
                        let parksTable = geodatabase.table(withLayerID: 1)
                        let preservesLayer = FeatureLayer(featureTable: preservesTable!)
                        let parksLayer = FeatureLayer(featureTable: parksTable!)
                        map.addOperationalLayer(preservesLayer)
                        map.addOperationalLayer(parksLayer)
                        await mapView.setViewpoint(Viewpoint(latitude: 65.399121, longitude: -151.521682, scale: 50000000))
                    } catch {
                        self.error = error
                    }
                }
        }
    }
}

extension URL {
    static var alaskaParksFeatureService: URL {
        URL(string: "https://services2.arcgis.com/ZQgQTuoyBrtmoGdP/ArcGIS/rest/services/AlaskaNationalParksPreserves_Update/FeatureServer")!
    }
}
