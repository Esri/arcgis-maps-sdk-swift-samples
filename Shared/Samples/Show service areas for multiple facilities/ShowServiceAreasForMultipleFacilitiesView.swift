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
    /// A map with a light gray basemap style.
    @State private var map = Map(basemapStyle: .arcGISLightGray)
    
    /// The service area task used to calculate the service area.
    @State private var serviceAreaTask = ServiceAreaTask(url: URL(string: "https://sampleserver7.arcgisonline.com/server/rest/services/NetworkAnalysis/SanDiego/NAServer/ServiceArea")!)
    
    /// The feature table that contains the facilities.
    @State private var facilitiesFeatureTable = ServiceFeatureTable(url: URL(string: "https://services2.arcgis.com/ZQgQTuoyBrtmoGdP/ArcGIS/rest/services/San_Diego_Facilities/FeatureServer/0")!)
    
    /// A graphics overlay which will hold the results of the service area
    /// calculation.
    @State private var graphicsOverlay = GraphicsOverlay()
    
    /// The error that occurred during calculating the service area.
    @State private var error: (any Error)?
    
    /// A Boolean value indicating if the service area is being calculated.
    @State private var isCalculatingServiceArea = false
    
    /// The service area fill symbols.
    let fillSymbols = [
        SimpleFillSymbol(color: .orange.withAlphaComponent(0.5)),
        SimpleFillSymbol(color: .red.withAlphaComponent(0.5))
    ]
    
    var body: some View {
        MapViewReader { mapViewProxy in
            MapView(map: map, graphicsOverlays: [graphicsOverlay])
                .overlay {
                    if isCalculatingServiceArea {
                        ProgressView("Calculating service area...")
                            .padding()
                            .background(.ultraThickMaterial)
                            .clipShape(.rect(cornerRadius: 10))
                            .shadow(radius: 15)
                    }
                }
                .task {
                    isCalculatingServiceArea = true
                    defer { isCalculatingServiceArea = false }
                    
                    do {
                        // Create a feature layer to display the facilities.
                        // Then add the facilities feature layer to the map.
                        let featureLayer = FeatureLayer(featureTable: facilitiesFeatureTable)
                        map.addOperationalLayer(featureLayer)
                        
                        // Load the facilities feature layer so that we can zoom
                        // to the full extent of the features.
                        try await featureLayer.load()
                        if let fullExtent = featureLayer.fullExtent {
                            await mapViewProxy.setViewpointGeometry(fullExtent, padding: 50)
                        }
                        
                        // Create default parameters for the service area task.
                        let serviceAreaParameters = try await serviceAreaTask.makeDefaultParameters()
                        // Set the facilities for which to calculate service area for.
                        serviceAreaParameters.setFacilities(fromFeaturesIn: facilitiesFeatureTable, queryParameters: .all())
                        // Specify that we want polygons returned, with a high
                        // level of detail.
                        serviceAreaParameters.returnsPolygons = true
                        serviceAreaParameters.polygonDetail = .high
                        // Set our impedance cutoffs to 1 minute and 3 minutes
                        // accordingly.
                        serviceAreaParameters.removeAllDefaultImpedanceCutoffs()
                        serviceAreaParameters.addDefaultImpedanceCutoffs([1, 3])
                        
                        // Solve the service area.
                        let serviceAreaResult = try await serviceAreaTask.solveServiceArea(
                            using: serviceAreaParameters
                        )
                        
                        // Loop through the service area facilities and add the
                        // results to the graphics overlay.
                        for index in serviceAreaResult.facilities.indices {
                            let resultPolygons = serviceAreaResult.resultPolygons(forFacilityAtIndex: index)
                            // There can be multiple polygons for each facility.
                            for (index, polygon) in resultPolygons.enumerated() {
                                graphicsOverlay
                                    .addGraphic(
                                        Graphic(geometry: polygon.geometry, symbol: fillSymbols[index])
                                    )
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
    /// Returns a query parameters with the where clause set to "1=1" so
    /// that all features will be returned.
    static func all() -> QueryParameters {
        let queryParameters = QueryParameters()
        queryParameters.whereClause = "1=1"
        return queryParameters
    }
}

#Preview {
    ShowServiceAreasForMultipleFacilitiesView()
}
