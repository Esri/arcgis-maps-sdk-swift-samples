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

struct FilterByDefinitionExpressionOrDisplayFilterView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// The draw status of the map view.
    @State private var drawStatus: DrawStatus?
    
    /// The count of features in the current extent of the map view.
    @State private var featureCount = 0
    
    /// The filtering mode selected in the picker.
    @State private var selectedFilterMode: FilterMode = .none
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    var body: some View {
        GeometryReader { geometryProxy in
            MapViewReader { mapViewProxy in
                MapView(map: model.map)
                    .onDrawStatusChanged { drawStatus = $0 }
                    .task(id: drawStatus) {
                        // Updates the feature count when the map view finishes drawing.
                        guard drawStatus == .completed else { return }
                        
                        // Creates an envelope from the frame of the map view.
                        let viewRect = geometryProxy.frame(in: .local)
                        guard let viewExtent = mapViewProxy.envelope(
                            fromViewRect: viewRect
                        ) else { return }
                        
                        do {
                            // Gets the feature count contained within the envelope.
                            featureCount = try await model.queryFeatureCount(extent: viewExtent)
                        } catch {
                            self.error = error
                        }
                    }
                    .errorAlert(presentingError: $error)
            }
        }
        .overlay(alignment: .top) {
            Text("Feature count: \(featureCount)")
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(8)
                .background(.regularMaterial, ignoresSafeAreaEdges: .horizontal)
        }
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Picker("Filter Mode", selection: $selectedFilterMode) {
                    ForEach(FilterMode.allCases, id: \.self) { filterMode in
                        Text(filterMode.label)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedFilterMode) { newFilterMode in
                    // Filters the feature layer based on the new filter mode.
                    model.filterFeatureLayer(filterMode: newFilterMode)
                }
            }
        }
    }
}

private extension FilterByDefinitionExpressionOrDisplayFilterView {
    /// The view model for the sample.
    final class Model: ObservableObject {
        /// A map with a topographic basemap.
        let map: Map = {
            let map = Map(basemapStyle: .arcGISTopographic)
            
            // Initially centers the map on San Fransisco, CA, USA.
            map.initialViewpoint = Viewpoint(
                center: Point(latitude: 37.7762, longitude: -122.4522),
                scale: 7e4
            )
            return map
        }()
        
        /// A feature layer of San Fransisco 311 incidents.
        private let featureLayer: FeatureLayer = {
            // Creates the feature layer from a feature service URL.
            let featureTable = ServiceFeatureTable(url: .sanFransiscoIncidentsFeatureLayer)
            return FeatureLayer(featureTable: featureTable)
        }()
        
        /// The parameters for querying the feature layer.
        private let queryParameters = QueryParameters()
        
        /// A definition expression to filter for the "Tree Maintenance or Damage" type.
        private let treesDefinitionExpression = "req_type = 'Tree Maintenance or Damage'"
        
        /// A display filter definition to filter for the "Tree Maintenance or Damage" type.
        private let treesDisplayFilterDefinition: ManualDisplayFilterDefinition = {
            // Creates a display filter with a name and an SQL expression.
            let treesDisplayFilter = DisplayFilter(
                name: "Trees",
                whereClause: "req_type LIKE 'Tree Maintenance or Damage'"
            )
            
            // Creates a display filter definition from the display filter.
            let treesDisplayFilterDefinition = ManualDisplayFilterDefinition(
                activeFilter: treesDisplayFilter,
                availableFilters: [treesDisplayFilter]
            )
            return treesDisplayFilterDefinition
        }()
        
        init() {
            map.addOperationalLayer(featureLayer)
        }
        
        /// Filters the feature layer based on a given filter mode.
        /// - Parameter filterMode: The mode indicating how to filter the layer.
        func filterFeatureLayer(filterMode: FilterMode) {
            // Sets the feature layer's definition expression.
            featureLayer.definitionExpression = filterMode == .definitionExpression
            ? treesDefinitionExpression
            : ""
            
            // Sets the feature layer's display filter definition.
            featureLayer.displayFilterDefinition = filterMode == .displayFilterDefinition
            ? treesDisplayFilterDefinition
            : nil
        }
        
        /// Queries the count of features on the feature layer within a given extent.
        /// - Parameter extent: The extent to query.
        /// - Returns: The number of features within the extent.
        func queryFeatureCount(extent: Envelope) async throws -> Int {
            guard let featureTable = featureLayer.featureTable else { return 0 }
            
            queryParameters.geometry = extent
            let featureCount = try await featureTable.queryFeatureCount(using: queryParameters)
            
            return featureCount
        }
    }
    
    /// The mode of filtering a feature layer.
    enum FilterMode: CaseIterable {
        case definitionExpression, displayFilterDefinition, none
        
        /// A human-readable label for the filter mode.
        var label: String {
            switch self {
            case .definitionExpression: "Expression"
            case .displayFilterDefinition: "Display Filter"
            case .none: "None"
            }
        }
    }
}

private extension URL {
    /// The URL to the "Incidents" feature layer on the SF 311 Incidents feature server.
    static var sanFransiscoIncidentsFeatureLayer: URL {
        URL(string: "https://services2.arcgis.com/ZQgQTuoyBrtmoGdP/arcgis/rest/services/SF_311_Incidents/FeatureServer/0")!
    }
}

#Preview {
    NavigationStack {
        FilterByDefinitionExpressionOrDisplayFilterView()
    }
}
