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

struct ShowServiceAreasForMultipleFacilitiesView: View {
    @State private var map = Map(basemapStyle: .arcGISLightGray)
    
    @State private var serviceAreaTask = ServiceAreaTask(url: URL(string: "https://sampleserver7.arcgisonline.com/server/rest/services/NetworkAnalysis/SanDiego/NAServer/Route")!)
    
    @State private var facilitiesFeatureTable = ServiceFeatureTable(url: URL(string: "https://services2.arcgis.com/ZQgQTuoyBrtmoGdP/ArcGIS/rest/services/San_Diego_Facilities/FeatureServer/0")!)
    
    @State private var graphicsOverlay = GraphicsOverlay()
    
    @State private var error: Error?
    
    var body: some View {
        MapViewReader { mapViewProxy in
            MapView(map: map, graphicsOverlays: [graphicsOverlay])
                .task {
                    do {
                        let featureLayer = FeatureLayer(featureTable: facilitiesFeatureTable)
                        map.addOperationalLayer(featureLayer)
                        try? await featureLayer.load()
                        if let fullExtent = featureLayer.fullExtent {
                            await mapViewProxy.setViewpointGeometry(fullExtent, padding: 50)
                        }
                        
                        try await facilitiesFeatureTable.load()
                        
                        let queryParameters = QueryParameters()
                        queryParameters.whereClause = "1=1"
                        let serviceAreaParameters = try await serviceAreaTask.makeDefaultParameters()
                        serviceAreaParameters.setFacilities(fromFeaturesIn: facilitiesFeatureTable, queryParameters: queryParameters)
                        serviceAreaParameters.returnsPolygons = true
                        serviceAreaParameters.polygonDetail = .high
                        serviceAreaParameters.removeAllDefaultImpedanceCutoffs()
                        serviceAreaParameters.addDefaultImpedanceCutoffs([1, 3])
                        
                        print("-- foo")
                        let serviceAreaResult = try await serviceAreaTask.solveServiceArea(using: serviceAreaParameters)
                        print("-- facs: \(serviceAreaResult.facilities)")
                        for index in serviceAreaResult.facilities.indices {
                            print("-- index: \(index)")
                            let polygons = serviceAreaResult.resultPolygons(forFacilityAtIndex: index)
                            for polygon in polygons {
                                print("-- poly: \(polygon.geometry.extent)")
                                let symbol = SimpleFillSymbol(color: .blue.withAlphaComponent(0.35))
                                graphicsOverlay.addGraphic(Graphic(geometry: polygon.geometry, symbol: symbol))
                            }
                        }
                    } catch {
                        print("-- error: \(error)")
                        self.error = error
                    }
                }
        }
    }
}

#Preview {
    ShowServiceAreasForMultipleFacilitiesView()
}
