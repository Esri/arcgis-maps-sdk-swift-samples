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

struct QueryFeatureCountAndExtentView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// A Boolean value indicating whether the feature count bar is showing.
    @State private var showFeatureCountBar = false
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    var body: some View {
        VStack {
            MapViewReader { proxy in
                MapView(map: model.map)
                // Perform update viewpoint.
                    .onViewpointChanged(kind: .boundingGeometry) { newViewpoint in
                        model.viewpoint = newViewpoint
                    }
                // Perform query when the selected state changes.
                    .onChange(of: model.selectedState) { _ in
                        Task {
                            do {
                                try await model.performQuery(on: proxy)
                                showFeatureCountBar = false
                            } catch {
                                self.error = error
                            }
                        }
                    }
            }
        }.overlay {
            GeometryReader { geometry in
                if showFeatureCountBar {
                    VStack {
                        Text("\(model.featureCountResult) feature(s) in extent")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(.thinMaterial, ignoresSafeAreaEdges: .horizontal)
                    }
                    .frame(width: geometry.size.width)
                    .transition(.move(edge: .top))
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                // Menu to select a state.
                Menu {
                    ForEach(model.stateAbbreviations, id: \.self) { abbreviation in
                        Button {
                            model.selectedState = abbreviation
                        } label: {
                            Text(abbreviation)
                        }
                    }
                } label: {
                    Text("Select State")
                }
                
                // Button to count features within the visible extent.
                Button("Count Features") {
                    Task {
                        do {
                            if let viewpoint = model.viewpoint {
                                try await model.performCountOnVisibleExtent(withinViewpoint: viewpoint)
                                showFeatureCountBar = true
                            }
                        } catch {
                            self.error = error
                        }
                    }
                }
            }
        }
        .errorAlert(presentingError: $error)
    }
}

private extension QueryFeatureCountAndExtentView {
    /// The view model for the sample.
    @MainActor
    class Model: ObservableObject {
        /// The map with a basemap and initial viewpoint.
        let map: Map = {
            let map = Map(basemapStyle: .arcGISDarkGray)
            map.initialViewpoint = Viewpoint(
                center: Point(x: -11e6, y: 5e6, spatialReference: .webMercator),
                scale: 9e7
            )
            return map
        }()
        
        /// The currently selected state abbreviation.
        @Published var selectedState: String?
        
        /// The count of features within the current viewpoint.
        @Published var featureCountResult: Int = 0
        
        /// The current viewpoint of the map.
        @Published var viewpoint: Viewpoint?
        
        /// The layer that displays features on the map.
        private let featureLayer: FeatureLayer
        
        /// The table for querying features from a server.
        private let featureTable: ServiceFeatureTable
        
        /// The list of state abbreviations for selection.
        let stateAbbreviations: [String] = [
            "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "DC", "FL", "GA", "HI",
            "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD", "MA", "MI", "MN",
            "MS", "MO", "MT", "NE", "NV", "NH", "NJ", "NM", "NY", "NC", "ND", "OH",
            "OK", "OR", "PA", "RI", "SC", "SD", "TN", "TX", "UT", "VT", "VA", "WA",
            "WV", "WI", "WY"
        ]
        
        init() {
            featureTable = ServiceFeatureTable(url: .medicareHospitalSpendLayer)
            featureLayer = FeatureLayer(featureTable: featureTable)
            map.addOperationalLayer(featureLayer)
        }
        
        /// Performs a query based on the selected state and updates the map viewpoint to encompass the results.
        /// - Parameter mapViewProxy: The proxy to update the map viewpoint.
        /// - Throws: An error if the query fails.
        func performQuery(on mapViewProxy: MapViewProxy?) async throws {
            guard let abbreviation = selectedState, !abbreviation.isEmpty else { return }
            featureLayer.clearSelection()
            let queryParameters = QueryParameters()
            queryParameters.whereClause = "State LIKE '%\(abbreviation)%'"
            
            let queryResult = try await featureTable.queryFeatures(using: queryParameters)
            let queryResultFeatures = Array(queryResult.features())
            
            if !queryResultFeatures.isEmpty {
                if let combinedExtent = GeometryEngine.combineExtents(
                    of: queryResultFeatures.compactMap(\.geometry)
                ) {
                    await mapViewProxy?.setViewpointGeometry(combinedExtent)
                }
            }
        }
        
        /// Counts the number of features within the specified viewpoint extent.
        /// - Parameter withinViewpoint: The viewpoint defining the extent to query.
        /// - Returns: The count of features within the specified extent.
        /// - Throws: An error if the count operation fails.
        func performCountOnVisibleExtent(withinViewpoint: Viewpoint?) async throws {
            let queryParameters = QueryParameters()
            queryParameters.geometry = withinViewpoint?.targetGeometry
            queryParameters.spatialRelationship = .intersects
            featureCountResult = try await featureLayer.featureTable!.queryFeatureCount(
                using: queryParameters
            )
        }
    }
}

private extension URL {
    /// The URL for the Medicare Hospital Spending layer service.
    static var medicareHospitalSpendLayer: URL {
        URL(string: "https://services1.arcgis.com/4yjifSiIG17X0gW4/arcgis/rest/services/Medicare_Hospital_Spending_per_Patient/FeatureServer/0")!
    }
}

#Preview {
    QueryFeatureCountAndExtentView()
}
