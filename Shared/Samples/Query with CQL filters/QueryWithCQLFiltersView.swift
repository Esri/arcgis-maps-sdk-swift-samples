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

struct QueryWithCQLFiltersView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// The count of feature from the last feature query result.
    @State private var resultFeatureCount = 0
    
    /// A Boolean value indicating whether the OCG feature collection table is currently being populated.
    @State private var isPopulatingFeatureTable = true
    
    /// A Boolean value indicating whether the CQL Filters form is presented.
    @State private var isShowingCQLFiltersForm = false
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    var body: some View {
        MapViewReader { mapViewProxy in
            MapView(map: model.map)
                .overlay(alignment: .top) {
                    Text(
                        isPopulatingFeatureTable
                        ? "Populating the feature table..."
                        : "Populated \(resultFeatureCount) features(s)."
                    )
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(8)
                    .background(.regularMaterial, ignoresSafeAreaEdges: .horizontal)
                }
                .toolbar {
                    ToolbarItem(placement: .bottomBar) {
                        Button("CQL Filters") {
                            isShowingCQLFiltersForm = true
                        }
                        .popover(isPresented: $isShowingCQLFiltersForm) {
                            CQLQueryFiltersForm(model: model) {
                                isPopulatingFeatureTable = true
                            }
                            .presentationDetents([.fraction(0.5)])
                            .frame(idealWidth: 320, idealHeight: 380)
                        }
                    }
                }
                .task(id: isPopulatingFeatureTable) {
                    guard isPopulatingFeatureTable else {
                        return
                    }
                    defer { isPopulatingFeatureTable = false }
                    
                    do {
                        // Queries the feature table using the query parameters.
                        let featureQueryResult = try await model.ogcFeatureCollectionTable
                            .populateFromService(using: model.queryParameters, clearCache: true)
                        
                        let queryResultFeatures = Array(featureQueryResult.features())
                        resultFeatureCount = queryResultFeatures.count
                        
                        // Sets the viewpoint to the extent of the query result.
                        let geometries = queryResultFeatures.compactMap(\.geometry)
                        if let combinedExtent = GeometryEngine.combineExtents(of: geometries) {
                            await mapViewProxy.setViewpointGeometry(combinedExtent, padding: 20)
                        }
                    } catch {
                        self.error = error
                    }
                }
                .errorAlert(presentingError: $error)
        }
    }
}

// MARK: - CQLQueryFiltersForm

private extension QueryWithCQLFiltersView {
    /// A form with filter controls for a CQL query.
    struct CQLQueryFiltersForm: View {
        /// The view model for the sample.
        @ObservedObject var model: Model
        
        /// The action to perform when the "Apply" button is pressed.
        let onApply: () -> Void
        
        /// The action to dismiss the view.
        @Environment(\.dismiss) private var dismiss
        
        /// The attribute expression that defines features to be included in the query.
        @State private var selectedWhereClause = ""
        
        /// The maximum number of features the query should return.
        @State private var maxFeatures = 1000
        
        /// A Boolean value indicating whether the query includes a time extent.
        @State private var includesDateFilter = false
        
        /// The start date of the query's time extent.
        @State private var selectedStartDate: Date = {
            let components = DateComponents(year: 2011, month: 6, day: 13)
            return Calendar.current.date(from: components)!
        }()
        
        /// The end date of the query's time extent.
        @State private var selectedEndDate: Date = {
            let components = DateComponents(year: 2012, month: 1, day: 7)
            return Calendar.current.date(from: components)!
        }()
        
        var body: some View {
            NavigationStack {
                Form {
                    Picker("Where Clause", selection: $selectedWhereClause) {
                        ForEach(model.sampleWhereClauses, id: \.self) { whereClause in
                            Text(whereClause)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    
                    LabeledContent("Max Features") {
                        TextField("1000", value: $maxFeatures, format: .number)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: maxFeatures) { newValue in
                                maxFeatures = newValue == 0 ? 1 : abs(newValue)
                            }
                    }
                    
                    Section {
                        Toggle("Date Filter", isOn: $includesDateFilter)
                        DatePicker(
                            "Start Date",
                            selection: $selectedStartDate,
                            in: ...selectedEndDate,
                            displayedComponents: [.date]
                        )
                        .disabled(!includesDateFilter)
                        DatePicker(
                            "End Date",
                            selection: $selectedEndDate,
                            in: selectedStartDate...,
                            displayedComponents: [.date]
                        )
                        .disabled(!includesDateFilter)
                    }
                }
                .navigationTitle("CQL Filters")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", role: .cancel) {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Apply") {
                            updateQueryParameters()
                            onApply()
                            dismiss()
                        }
                    }
                }
            }
            .onAppear {
                // Sets the control's initial state using the values from the last query.
                selectedWhereClause = model.queryParameters.whereClause
                maxFeatures = model.queryParameters.maxFeatures
                
                if let timeExtent = model.queryParameters.timeExtent {
                    includesDateFilter = true
                    selectedStartDate = timeExtent.startDate!
                    selectedEndDate = timeExtent.endDate!
                }
            }
        }
        
        /// Updates the model's query parameters using the values from the form.
        private func updateQueryParameters() {
            model.queryParameters.whereClause = selectedWhereClause
            model.queryParameters.maxFeatures = maxFeatures
            
            model.queryParameters.timeExtent = includesDateFilter
            ? TimeExtent(startDate: selectedStartDate, endDate: selectedEndDate)
            : nil
        }
    }
}

// MARK: - Model

private extension QueryWithCQLFiltersView {
    /// The view model for the sample.
    final class Model: ObservableObject {
        /// A map with a topographic basemap.
        let map: Map = {
            let map = Map(basemapStyle: .arcGISTopographic)
            map.initialViewpoint = Viewpoint(latitude: 32.62, longitude: 36.10, scale: 20_000)
            return map
        }()
        
        /// An OGC API - Features feature collection table for the "Daraa" test dataset.
        let ogcFeatureCollectionTable: OGCFeatureCollectionTable = {
            let table = OGCFeatureCollectionTable(
                url: URL(string: "https://demo.ldproxy.net/daraa")!,
                collectionID: "TransportationGroundCrv"
            )
            // Sets the feature request mode to manual. In this mode, the table must be populated
            // manually. Panning and zooming won't request features automatically.
            table.featureRequestMode = .manualCache
            return table
        }()
        
        /// The sample where clause expressions to use with the query parameters.
        let sampleWhereClauses: [String] = [
            // An empty query.
            "",
            // A CQL2 TEXT query for features with an F_CODE property of "AP010".
            "F_CODE = 'AP010'",
            // A CQL2 JSON query for features with an F_CODE property of "AP010".
            #"{ "op": "=", "args": [ { "property": "F_CODE" }, "AP010" ] }"#,
            // A CQL2 TEXT query for features with an F_CODE attribute property similar to "AQ".
            "F_CODE LIKE 'AQ%'",
            // A CQL2 JSON query that combines the "before" and "eq" operators
            // with the logical "and" operator.
            #"{"op": "and", "args":[{ "op": "=", "args":[{ "property" : "F_CODE" }, "AP010"]}, { "op": "t_before", "args":[{ "property" : "ZI001_SDV"},"2013-01-01"]}]}"#
        ]
        
        /// The parameters for filtering the features returned form a query.
        let queryParameters: QueryParameters = {
            let queryParameters = QueryParameters()
            queryParameters.maxFeatures = 1000
            return queryParameters
        }()
        
        init() {
            // Creates a feature layer to visualize the OGC API features and adds it to the map.
            let ogcFeatureLayer = FeatureLayer(featureTable: ogcFeatureCollectionTable)
            let redLineSymbol = SimpleLineSymbol(style: .solid, color: .red, width: 3)
            ogcFeatureLayer.renderer = SimpleRenderer(symbol: redLineSymbol)
            
            map.addOperationalLayer(ogcFeatureLayer)
        }
    }
}

#Preview {
    QueryWithCQLFiltersView()
}
