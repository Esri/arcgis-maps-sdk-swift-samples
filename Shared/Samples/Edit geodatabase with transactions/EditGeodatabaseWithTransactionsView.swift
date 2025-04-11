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

struct EditGeodatabaseWithTransactionsView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// The action currently being preformed.
    @State private var selectedAction: Action? = .setUp
    
    /// The text describing the status of the sample.
    @State private var statusText = ""
    
    /// The point on the map where the user tapped.
    @State private var tapLocation: Point?
    
    /// A Boolean value indicating whether a transaction is active on the geodatabase.
    @State private var isInTransaction = false
    
    /// A Boolean value indicating whether a transaction is required to add a feature.
    @State private var transactionIsRequired = true
    
    /// A Boolean value indicating whether the select feature type popover is presented.
    @State private var isSelectingFeatureType = false
    
    /// A Boolean value indicating whether the alert to end a transaction is presented.
    @State private var endTransactionAlertIsPresented = false
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    var body: some View {
        MapView(map: model.map)
            .onSingleTapGesture { _, mapPoint in
                // Shows the select feature type popover when a feature can currently be added.
                guard !transactionIsRequired || isInTransaction else { return }
                
                tapLocation = mapPoint
                isSelectingFeatureType = true
            }
            .task(id: selectedAction) {
                guard let selectedAction else { return }
                
                do {
                    switch selectedAction {
                    case .setUp:
                        try await model.setUp()
                    case .addFeature(let tableName, let featureTypeName):
                        try await model.addFeature(
                            tableName: tableName,
                            featureTypeName: featureTypeName,
                            point: tapLocation!
                        )
                    case .beginTransaction:
                        try model.geodatabase.beginTransaction()
                        isInTransaction = true
                    case .commitTransaction:
                        try model.geodatabase.commitTransaction()
                        isInTransaction = false
                    case .rollbackTransaction:
                        try model.geodatabase.rollbackTransaction()
                        isInTransaction = false
                    }
                    
                    statusText = selectedAction.completionMessage
                } catch GeodatabaseError.geometryOutsideReplicaExtent {
                    statusText = "Error: Feature geometry is outside the generate geodatabase geometry."
                } catch {
                    self.error = error
                }
                
                self.selectedAction = nil
            }
            .overlay(alignment: .top) {
                Text(statusText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(8)
                    .background(.regularMaterial, ignoresSafeAreaEdges: .horizontal)
            }
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button(isInTransaction ? "End Transaction" : "Start Transaction") {
                        if isInTransaction {
                            // Presents the alert to handle the edits.
                            endTransactionAlertIsPresented = true
                        } else {
                            selectedAction = .beginTransaction
                        }
                    }
                    .disabled(!transactionIsRequired)
                    .popover(isPresented: $isSelectingFeatureType) {
                        SelectFeatureTypeView(
                            featureTables: model.geodatabase.featureTables
                        ) { tableName, featureTypeName in
                            selectedAction = .addFeature(
                                tableName: tableName,
                                featureTypeName: featureTypeName
                            )
                        }
                        .presentationDetents([.fraction(0.5)])
                        .frame(idealWidth: 320, idealHeight: 380)
                    }
                    
                    Spacer()
                    
                    Toggle("Requires Transaction", isOn: $transactionIsRequired)
                        .disabled(isInTransaction)
                        .onChange(of: transactionIsRequired) {
                            statusText = transactionIsRequired
                            ? "Tap Start to begin a transaction."
                            : "Tap on the map to add a feature."
                        }
                }
            }
            .alert("Commit Edits", isPresented: $endTransactionAlertIsPresented) {
                Button("Commit") {
                    selectedAction = .commitTransaction
                }
                Button("Rollback", role: .destructive) {
                    selectedAction = .rollbackTransaction
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Commit the edits in the transaction to the geodatabase or rollback to discard them.")
            }
            .disabled(selectedAction == .setUp)
            .errorAlert(presentingError: $error)
    }
}

/// An action associated with the geodatabase.
private enum Action: Equatable {
    /// Sets up the sample.
    case setUp
    /// Adds a feature of a given type to a table in the geodatabase.
    case addFeature(tableName: String, featureTypeName: String)
    /// Starts a transaction on the geodatabase.
    case beginTransaction
    /// Commits the edits in the transaction to the geodatabase.
    case commitTransaction
    /// Rollback the edits in the transaction from the geodatabase.
    case rollbackTransaction
    
    /// The message to display when the action successfully completes.
    var completionMessage: String {
        switch self {
        case .setUp: "Tap Start to begin a transaction."
        case .addFeature: "Added feature."
        case .beginTransaction: "Transaction started."
        case .commitTransaction: "Edits committed to geodatabase."
        case .rollbackTransaction: "Edits discarded."
        }
    }
}

/// A view allowing the user to select a feature type from given feature tables.
private struct SelectFeatureTypeView: View {
    /// The feature tables containing the feature types.
    let featureTables: [ArcGISFeatureTable]
    
    /// The action to perform when a feature type is selected and the "Done" button is pressed.
    let onFeatureSelectionAction: (_ tableName: String, _ featureTypeName: String) -> Void
    
    /// The action to dismiss the view.
    @Environment(\.dismiss) private var dismiss
    
    /// The name of the feature table selected in the picker.
    @State private var selectedFeatureTableName = ""
    
    /// The name of the feature type selected by the user.
    @State private var selectedFeatureTypeName: String?
    
    /// The feature types of the selected feature table.
    private var featureTypeOptions: [FeatureType] {
        let selectFeatureTable = featureTables.first { $0.tableName == selectedFeatureTableName }
        return selectFeatureTable?.featureTypes ?? []
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Feature Type") {
                    Picker("Feature Table", selection: $selectedFeatureTableName) {
                        ForEach(featureTables, id: \.tableName) { featureTable in
                            Text(featureTable.displayName)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Picker("Feature Type", selection: $selectedFeatureTypeName) {
                        ForEach(featureTypeOptions, id: \.name) { featureType in
                            Text(featureType.name)
                                .tag(featureType.name as String?)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
            .navigationTitle("New Feature")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onFeatureSelectionAction(selectedFeatureTableName, selectedFeatureTypeName!)
                        dismiss()
                    }
                    .disabled(selectedFeatureTypeName == nil)
                }
            }
        }
        .onAppear {
            selectedFeatureTableName = featureTables.first?.tableName ?? ""
        }
    }
}

#Preview {
    NavigationStack {
        EditGeodatabaseWithTransactionsView()
    }
}
