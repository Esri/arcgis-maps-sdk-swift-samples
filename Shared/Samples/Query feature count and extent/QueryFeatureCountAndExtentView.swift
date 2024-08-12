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
    @State private var showFeatureCountBar = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        ZStack {
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
                                } catch {
                                    alertMessage = "Failed to perform query: \(error.localizedDescription)"
                                    showAlert = true
                                }
                            }
                        }
                }
                
                Spacer()
                
                HStack {
                    Button("Select State") {
                        model.showPopup.toggle()
                    }
                    
                    Spacer()
                    
                    Button("Count Features") {
                        // Perform feature count.
                        Task {
                            do {
                                if let viewpoint = model.viewpoint {
                                    model.featureCountResult = try await model.performCountOnVisibleExtent(
                                        withinViewpoint: viewpoint
                                    )
                                    showFeatureCountBar = true
                                }
                            } catch {
                                alertMessage = "Failed to count features: \(error.localizedDescription)"
                                showAlert = true
                            }
                        }
                    }
                }
                .padding()
            }
            
            if showFeatureCountBar {
                VStack {
                    if let featureCountResult = model.featureCountResult {
                        Text("\(featureCountResult) feature(s) in extent")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(.thinMaterial, ignoresSafeAreaEdges: .horizontal)
                    }
                    Spacer()
                }
            }
            
            if model.showPopup {
                ZoomAndExtendPopup(
                    showPopup: $model.showPopup,
                    selectedState: $model.selectedState,
                    stateAbbreviations: model.stateAbbreviations
                )
                .transition(.opacity)
                .zIndex(1)
                .frame(width: 300, height: 200)
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Error"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
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
        
        /// A boolean value that determines if the popup is shown.
        @Published var showPopup = false
        
        /// The current state abbreviation selected in the popup.
        @Published var selectedState: String?
        
        /// The count of features within the current viewpoint.
        @Published var featureCountResult: Int?
        
        /// The current viewpoint of the map.
        @Published var viewpoint: Viewpoint?
        
        /// List of state abbreviations for use in select states.
        let stateAbbreviations: [String] = [
            "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "DC", "FL", "GA", "HI",
            "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD", "MA", "MI", "MN",
            "MS", "MO", "MT", "NE", "NV", "NH", "NJ", "NM", "NY", "NC", "ND", "OH",
            "OK", "OR", "PA", "RI", "SC", "SD", "TN", "TX", "UT", "VT", "VA", "WA",
            "WV", "WI", "WY"
        ]
        
        private let featureLayer: FeatureLayer
        private let featureTable: ServiceFeatureTable
        
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
        /// - Parameter withinViewpoint: The viewpoint defining the extent to query
        /// - Returns: The count of features within the specified extent.
        /// - Throws: An error if the count operation fails.
        func performCountOnVisibleExtent(withinViewpoint: Viewpoint?) async throws -> Int {
            let queryParameters = QueryParameters()
            queryParameters.geometry = withinViewpoint?.targetGeometry
            queryParameters.spatialRelationship = .intersects
            let count = try await featureLayer.featureTable!.queryFeatureCount(
                using: queryParameters
            )
            return count
        }
    }
}

/// A view that provides a popup for selecting a state and zooming to features.
struct ZoomAndExtendPopup: View {
    @Binding var showPopup: Bool
    @Binding var selectedState: String?
    @State private var tempSelectedState: String = "AL"
    let stateAbbreviations: [String]
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                Text("Click 'Zoom' to zoom to features matching the given state abbreviation.")
                    .multilineTextAlignment(.center)
                    .padding()
                
                Picker("Select States", selection: $tempSelectedState) {
                    ForEach(stateAbbreviations, id: \.self) { abbreviation in
                        Text(abbreviation).tag(abbreviation as String?)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                
                HStack {
                    Button("Cancel") {
                        showPopup = false
                    }
                    
                    Spacer()
                    
                    Button("Zoom") {
                        selectedState = tempSelectedState
                        showPopup = false
                    }
                }
                .padding()
            }
            .frame(width: 300, height: 200)
            .background(Color.white)
            .cornerRadius(10)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }
}

private extension URL {
    /// URL for the Medicare Hospital Spending layer service.
    static var medicareHospitalSpendLayer: URL {
        URL(string: "https://services1.arcgis.com/4yjifSiIG17X0gW4/arcgis/rest/services/Medicare_Hospital_Spending_per_Patient/FeatureServer/0")!
    }
}

#Preview {
    QueryFeatureCountAndExtentView()
}
