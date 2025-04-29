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

@MainActor
struct AddWFSLayerView: View {
    /// A map with a topographic basemap.
    @State private var map = Map(basemapStyle: .arcGISTopographic)
    
    /// The visible area on the map.
    @State private var visibleArea: ArcGIS.Polygon?
    
    /// A feature table of building footprints for downtown Seattle.
    @State private var featureTable: WFSFeatureTable = {
        let featureTable = WFSFeatureTable(url: .downtownSeattle, tableName: "Seattle_Downtown_Features:Buildings")
        // Sets the feature request mode to manual. In this mode, the table must be populated
        // manually. Panning and zooming won't request features automatically.
        featureTable.featureRequestMode = .manualCache
        // Sets the axis order.
        featureTable.axisOrder = .noSwap
        return featureTable
    }()
    
    /// A Boolean value indicating whether the map view is currently navigating.
    @State private var mapIsNavigating = false
    
    /// A Boolean value indicating whether the feature table is being populated.
    @State private var isPopulating = true
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    var body: some View {
        MapViewReader { mapViewProxy in
            MapView(map: map)
                .onVisibleAreaChanged { visibleArea = $0 }
                .onNavigatingChanged { mapIsNavigating = $0 }
                .task {
                    do {
                        try await featureTable.load()
                        let wfsFeatureLayer = FeatureLayer(featureTable: featureTable)
                        wfsFeatureLayer.renderer = SimpleRenderer(
                            symbol: SimpleLineSymbol(
                                style: .solid,
                                color: .red,
                                width: 3
                            )
                        )
                        map.addOperationalLayer(wfsFeatureLayer)
                        
                        await mapViewProxy.setViewpoint(
                            Viewpoint(
                                boundingGeometry: Envelope(
                                    xRange: -122.341581 ... -122.332662,
                                    yRange: 47.613758...47.617207,
                                    spatialReference: .wgs84
                                )
                            )
                        )
                    } catch {
                        // Present an alert for an error loading a layer.
                        self.error = error
                    }
                }
                .task(id: mapIsNavigating) {
                    guard !mapIsNavigating else { return }
                    do {
                        guard let extent = visibleArea?.extent else { return }
                        try await populateFeatures(within: extent)
                    } catch {
                        self.error = error
                    }
                }
                .overlay(alignment: .center) {
                    if isPopulating {
                        VStack {
                            Text("Populating")
                            ProgressView()
                                .progressViewStyle(.circular)
                        }
                        .padding()
                        .background(.ultraThickMaterial)
                        .clipShape(.rect(cornerRadius: 10))
                        .shadow(radius: 50)
                    }
                }
                .errorAlert(presentingError: $error)
        }
    }
    
    /// Populates the feature table using queried features contained within a given geometry.
    /// - Parameter geometry: The geometry used to filter the results.
    private func populateFeatures(within geometry: Geometry) async throws {
        isPopulating = true
        defer { isPopulating = false }
        
        let queryParameters = QueryParameters()
        queryParameters.geometry = geometry
        queryParameters.spatialRelationship = .intersects
        _ = try await featureTable.populateFromService(
            using: queryParameters,
            clearCache: false,
            outFields: []
        )
    }
}

private extension URL {
    /// Downtown Seattle feature service URL used to create a feature layer.
    static var downtownSeattle: URL {
        URL(string: "https://dservices2.arcgis.com/ZQgQTuoyBrtmoGdP/arcgis/services/Seattle_Downtown_Features/WFSServer?service=wfs&request=getcapabilities")!
    }
}

#Preview {
    AddWFSLayerView()
}
