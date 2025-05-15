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
    
    @State private var serviceAreaTask = ServiceAreaTask(url: URL(string: "https://sampleserver7.arcgisonline.com/server/rest/services/NetworkAnalysis/SanDiego/NAServer/ServiceArea")!)
    
    @State private var facilitiesFeatureTable = ServiceFeatureTable(url: URL(string: "https://services2.arcgis.com/ZQgQTuoyBrtmoGdP/ArcGIS/rest/services/San_Diego_Facilities/FeatureServer/0")!)
    
    @State private var graphicsOverlay = GraphicsOverlay()
    
    @State private var error: Error?
    
    @State private var isCalculatingServiceArea = false
    
    var body: some View {
        MapViewReader { mapViewProxy in
            MapView(map: map, graphicsOverlays: [graphicsOverlay])
                .overlay {
                    if isCalculatingServiceArea {
                        ProgressView("Calculating service area...")
                            .padding()
                            .background(.ultraThickMaterial)
                            .clipShape(.rect(cornerRadius: 10))
                            .shadow(radius: 50)
                    }
                }
                .task {
                    isCalculatingServiceArea = true
                    defer { isCalculatingServiceArea = false }
                    do {
                        let featureLayer = FeatureLayer(featureTable: facilitiesFeatureTable)
                        map.addOperationalLayer(featureLayer)
                        try await featureLayer.load()
                        if let fullExtent = featureLayer.fullExtent {
                            await mapViewProxy.setViewpointGeometry(fullExtent, padding: 50)
                        }
                        
                        let serviceAreaParameters = try await serviceAreaTask.makeDefaultParameters()
                        serviceAreaParameters.setFacilities(fromFeaturesIn: facilitiesFeatureTable, queryParameters: .all)
                        serviceAreaParameters.returnsPolygons = true
                        serviceAreaParameters.polygonDetail = .high
                        serviceAreaParameters.addDefaultImpedanceCutoffs([1, 3])
                        
                        let serviceAreaResult = try await serviceAreaTask.solveServiceArea(using: serviceAreaParameters)
                        for index in serviceAreaResult.facilities.indices {
                            let polygons = serviceAreaResult.resultPolygons(forFacilityAtIndex: index)
                            for polygon in polygons {
                                let symbol = SimpleFillSymbol(color: .blue.withAlphaComponent(0.35))
                                graphicsOverlay.addGraphic(Graphic(geometry: polygon.geometry, symbol: symbol))
                            }
                        }
                    } catch {
                        self.error = error
                    }
                }
        }
    }
}

private extension QueryParameters {
    static let all = {
        let queryParameters = QueryParameters()
        queryParameters.whereClause = "1=1"
        return queryParameters
    }()
}

#Preview {
    ShowServiceAreasForMultipleFacilitiesView()
}
