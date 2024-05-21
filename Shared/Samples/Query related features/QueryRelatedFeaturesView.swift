// Copyright 2024 Esri
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

struct QueryRelatedFeaturesView: View {
    /// A map with a topographic basemap.
    @State private var map: Map = {
        let map = Map(basemapStyle: .arcGISTopographic)
        
        // Creates and adds feature tables to the map to allow related feature querying.
        let preservesFeatureTable = ServiceFeatureTable(
            url: .alaskaParksFeatureServer.appending(component: "0")
        )
        let speciesFeatureTable = ServiceFeatureTable(
            url: .alaskaParksFeatureServer.appending(component: "2")
        )
        map.addTables([preservesFeatureTable, speciesFeatureTable])
        
        return map
    }()
    
    /// An "Alaska National Parks" feature layer.
    @State private var parksFeatureLayer = FeatureLayer(
        featureTable: ServiceFeatureTable(
            url: .alaskaParksFeatureServer.appending(component: "1")
        )
    )
    /// The text describing the loading status of the sample.
    @State private var loadingStatusText: String?
    
    /// The point on the screen where the user tapped.
    @State private var tapPoint: CGPoint?
    
    /// The results from querying related features.
    @State private var queryResults: RelatedFeatureQueryResults?
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    var body: some View {
        GeometryReader { geometryProxy in
            MapViewReader { mapViewProxy in
                MapView(map: map)
                    .onSingleTapGesture { screenPoint, _ in
                        tapPoint = screenPoint
                    }
                    .task(id: tapPoint) {
                        guard let tapPoint else { return }
                        parksFeatureLayer.clearSelection()
                        
                        do {
                            // Identifies the tapped screen point.
                            loadingStatusText = "Identifying feature…"
                            defer { loadingStatusText = nil }
                            
                            let identifyResult = try await mapViewProxy.identify(
                                on: parksFeatureLayer,
                                screenPoint: tapPoint,
                                tolerance: 12
                            )
                            
                            // Selects the first feature in the result.
                            guard let parkFeature = identifyResult.geoElements.first
                                    as? ArcGISFeature else { return }
                            parksFeatureLayer.selectFeature(parkFeature)
                            
                            // Queries for related features of the identified feature.
                            loadingStatusText = "Querying related features…"
                            
                            let parksFeatureTable = parksFeatureLayer.featureTable as! ServiceFeatureTable
                            let queryResults = try await parksFeatureTable.queryRelatedFeatures(
                                to: parkFeature
                            )
                            self.queryResults = RelatedFeatureQueryResults(results: queryResults)
                        } catch {
                            self.error = error
                        }
                    }
                    .popover(
                        item: $queryResults,
                        attachmentAnchor: .point(tapPoint?.unitPoint(for: geometryProxy.size) ?? .zero)
                    ) { newQueryResults in
                        RelatedFeaturesList(results: newQueryResults.results)
                            .frame(idealWidth: 320, idealHeight: 380)
                            .onDisappear(perform: parksFeatureLayer.clearSelection)
                    }
                    .overlay(alignment: .center) {
                        // Shows a progress view when there is a loading status.
                        if let loadingStatusText {
                            VStack {
                                Text(loadingStatusText)
                                ProgressView()
                            }
                            .padding()
                            .background(.ultraThickMaterial)
                            .cornerRadius(10)
                            .shadow(radius: 50)
                        }
                    }
                    .task {
                        // Loads the parks feature layer and zooms the viewpoint to its extent.
                        do {
                            loadingStatusText = "Loading feature layer…"
                            defer { loadingStatusText = nil }
                            
                            try await parksFeatureLayer.load()
                            map.addOperationalLayer(parksFeatureLayer)
                            
                            guard let parksLayerExtent = parksFeatureLayer.fullExtent else { return }
                            await mapViewProxy.setViewpointGeometry(parksLayerExtent, padding: 20)
                        } catch {
                            self.error = error
                        }
                    }
                    .errorAlert(presentingError: $error)
            }
        }
    }
}

private extension QueryRelatedFeaturesView {
    /// A list of features from given related feature query results.
    struct RelatedFeaturesList: View {
        /// The results to display in the list.
        let results: [RelatedFeatureQueryResult]
        
        /// The action to dismiss the view.
        @Environment(\.dismiss) private var dismiss
        
        var body: some View {
            NavigationStack {
                List {
                    ForEach(Array(results.enumerated()), id: \.offset) { offset, result in
                        let relatedTableName = result.relatedTable?.tableName
                        Section(relatedTableName ?? "Feature Table \(offset + 1)") {
                            ForEach(result.featureDisplayNames, id: \.self) { featureName in
                                Text(featureName)
                            }
                        }
                    }
                }
                .navigationTitle(
                    results.first?.feature?.attributes["UNIT_NAME"] as? String ?? "Origin Feature"
                )
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            }
        }
    }
    
    /// A struct containing the results from a related features query.
    struct RelatedFeatureQueryResults: Identifiable {
        /// A universally unique id to identify the type.
        let id = UUID()
        /// The related feature query results.
        let results: [RelatedFeatureQueryResult]
    }
}

private extension RelatedFeatureQueryResult {
    /// The display names of the result's features.
    var featureDisplayNames: [String] {
        guard let displayFieldName = relatedTable?.layerInfo?.displayFieldName else { return [] }
        return features()
            .compactMap { $0.attributes[displayFieldName] as? String }
            .sorted()
    }
}

private extension CGPoint {
    /// The unit point for a given size.
    /// - Parameter size: The size of the view.
    /// - Returns: A `UnitPoint` for the point.
    func unitPoint(for size: CGSize) -> UnitPoint {
        UnitPoint(x: x / size.width, y: y / size.height)
    }
}

private extension URL {
    /// The URL to the "Alaska National Parks Preserves Species" feature server.
    static var alaskaParksFeatureServer: URL {
        URL(string: "https://services2.arcgis.com/ZQgQTuoyBrtmoGdP/arcgis/rest/services/AlaskaNationalParksPreservesSpecies_List/FeatureServer")!
    }
}

#Preview {
    QueryRelatedFeaturesView()
}
