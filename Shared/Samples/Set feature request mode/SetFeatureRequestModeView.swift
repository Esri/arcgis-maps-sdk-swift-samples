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

struct SetFeatureRequestModeView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// The feature table's current feature request mode.
    @State private var selectedFeatureRequestMode: FeatureRequestMode = .onInteractionCache
    
    /// The text shown in the overlay at the top of the screen.
    @State private var message = ""
    
    /// A Boolean value indicating whether the feature table is being populated.
    @State private var isPopulating = false
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    var body: some View {
        GeometryReader { geometryProxy in
            MapViewReader { mapViewProxy in
                MapView(map: model.map)
                    .overlay(alignment: .top) {
                        Text(message)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(8)
                            .background(.thinMaterial, ignoresSafeAreaEdges: .horizontal)
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .bottomBar) {
                            Button("Populate") {
                                isPopulating = true
                            }
                            .disabled(selectedFeatureRequestMode != .manualCache)
                            .task(id: isPopulating) {
                                // Populate the feature table when the "Populate" button is tapped.
                                guard isPopulating else { return }
                                defer { isPopulating = false }
                                
                                do {
                                    // Get the current extent of the screen.
                                    let viewRect = geometryProxy.frame(in: .local)
                                    let viewExtent = mapViewProxy.envelope(fromViewRect: viewRect)
                                    
                                    // Populate the feature table with features contained in extent.
                                    let count = try await model.populateFeatures(within: viewExtent)
                                    message = "Populated \(count) features."
                                } catch {
                                    self.error = error
                                }
                            }
                            
                            Picker("Feature Request Mode", selection: $selectedFeatureRequestMode) {
                                ForEach(FeatureRequestMode.modeCases, id: \.self) { mode in
                                    Text(mode.label)
                                }
                            }
                            .onChange(of: selectedFeatureRequestMode) { newMode in
                                // Update the feature table's feature request mode.
                                model.featureTable.featureRequestMode = newMode
                                message = "\(model.featureTable.featureRequestMode.label) enabled."
                            }
                        }
                    }
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
                .cornerRadius(10)
                .shadow(radius: 50)
            }
        }
        .errorAlert(presentingError: $error)
    }
}

private extension SetFeatureRequestModeView {
    /// The view model for the sample.
    class Model: ObservableObject {
        /// A map with a topographic basemap centered on Portland OR, USA.
        let map: Map = {
            let map = Map(basemapStyle: .arcGISTopographic)
            map.initialViewpoint = Viewpoint(latitude: 45.5266, longitude: -122.6219, scale: 6e3)
            return map
        }()
        
        /// The service feature table.
        let featureTable: ServiceFeatureTable = {
            // Create the table from a URL.
            let featureTable = ServiceFeatureTable(url: .treesOfPortland)
            
            // Set the initial table's feature request mode.
            featureTable.featureRequestMode = .onInteractionCache
            
            return featureTable
        }()
        
        init() {
            // Create a feature layer from the feature table and add it to the map.
            let featureLayer = FeatureLayer(featureTable: featureTable)
            map.addOperationalLayer(featureLayer)
        }
        
        /// Populates the feature table using queried features contained within a given geometry.
        /// - Parameter geometry: The geometry used to filter the results.
        /// - Returns: The number of features populated.
        func populateFeatures(within geometry: Geometry?) async throws -> Int {
            // Create query parameters to filter for all tree
            // conditions except "dead" (coded value '4').
            let queryParameters = QueryParameters()
            queryParameters.whereClause = "Condition < '4'"
            queryParameters.geometry = geometry
            
            // Use the query parameters to populate the feature table.
            let featureQueryResult = try await featureTable.populateFromService(
                using: queryParameters,
                clearCache: true,
                outFields: ["*"]
            )
            
            // Get the amount of features found from the feature query result.
            let featureCount = featureQueryResult.features().reduce(into: Int()) { result, _ in
                result += 1
            }
            return featureCount
        }
    }
}

private extension FeatureRequestMode {
    /// The feature request mode cases that represent a valid mode, e.i., not `undefined`.
    static var modeCases: [Self] {
        return [.onInteractionCache, .onInteractionNoCache, .manualCache]
    }
    
    /// A human-readable label for the feature request mode.
    var label: String {
        switch self {
        case .undefined:
            return "Undefined"
        case .manualCache:
            return "Manual Cache"
        case .onInteractionCache:
            return "Cache"
        case .onInteractionNoCache:
            return "No Cache"
        @unknown default:
            return "Unknown"
        }
    }
}

private extension URL {
    /// A URL to a feature layer from the "Trees of Portland" feature service.
    static var treesOfPortland: URL {
        URL(string: "https://services2.arcgis.com/ZQgQTuoyBrtmoGdP/arcgis/rest/services/Trees_of_Portland/FeatureServer/0")!
    }
}

#Preview {
    NavigationView {
        SetFeatureRequestModeView()
    }
}
