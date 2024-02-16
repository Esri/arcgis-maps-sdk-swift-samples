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

struct ValidateUtilityNetworkTopologyView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// The visible area on the map.
    @State private var visibleArea: ArcGIS.Polygon?
    
    /// The operation on the model currently being executed.
    @State private var selectedOperation: ModelOperation = .setup
    
    /// A Boolean value indicating whether a model operation is in progress.
    @State private var operationIsRunning = false
    
    /// A Boolean value indicating whether the edit feature sheet is presented.
    @State private var editSheetIsPresented = false
    
    /// A Boolean value indicating whether the details of the status message are presented.
    @State private var statusDetailsArePresented = false
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    var body: some View {
        MapViewReader { mapViewProxy in
            MapView(map: model.map, graphicsOverlays: [model.graphicsOverlay])
                .onVisibleAreaChanged { visibleArea = $0 }
                .onSingleTapGesture { screenPoint, _ in
                    selectedOperation = .selectFeature(screenPoint: screenPoint)
                }
                .contentInsets(.init(top: 0, leading: 0, bottom: 350, trailing: 0))
                .task(id: selectedOperation) {
                    operationIsRunning = true
                    defer { operationIsRunning = false }
                    
                    do {
                        switch selectedOperation {
                        case .setup:
                            try await model.setup()
                            
                        case .getState:
                            try await model.getState()
                            
                        case .trace:
                            try await model.trace()
                            
                        case .validateNetworkTopology:
                            guard let extent = visibleArea?.extent else { return }
                            try await model.validate(forExtent: extent)
                            
                        case .selectFeature(let screenPoint):
                            // Identify the tapped layers using the map view proxy.
                            let identifyResults = try await mapViewProxy.identifyLayers(
                                screenPoint: screenPoint!,
                                tolerance: 5
                            )
                            model.selectFeature(from: identifyResults)
                            
                            // Present the sheet to edit the feature if one was selected.
                            if let feature = model.feature {
                                editSheetIsPresented = true
                                
                                guard let featureCenter = feature.geometry?.extent.center else { return }
                                await mapViewProxy.setViewpointCenter(featureCenter)
                            } else {
                                model.statusMessage = "No feature identified. Tap on a feature."
                            }
                            
                        case .applyEdits:
                            try await model.applyEdits()
                            
                        case .clearSelection:
                            model.clearSelection()
                            model.statusMessage = "Selection cleared."
                        }
                    } catch {
                        model.statusMessage = selectedOperation.errorMessage
                        self.error = error
                    }
                }
        }
        .overlay(alignment: .top) {
            CollapsibleText(text: $model.statusMessage)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(8)
                .background(.ultraThinMaterial, ignoresSafeAreaEdges: .horizontal)
        }
        .overlay(alignment: .center) {
            if operationIsRunning {
                ProgressView()
                    .padding()
                    .background(.ultraThickMaterial)
                    .cornerRadius(10)
                    .shadow(radius: 50)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button("Get State") { selectedOperation = .getState }
                    .disabled(!model.canGetState)
                Spacer()
                Button("Trace") { selectedOperation = .trace }
                    .disabled(!model.canTrace)
                Spacer()
                Button("Validate") { selectedOperation = .validateNetworkTopology }
                    .disabled(!model.canValidateNetworkTopology)
                Spacer()
                Button("Clear") { selectedOperation = .clearSelection }
                    .disabled(!model.canClearSelection)
                    .sheet(isPresented: $editSheetIsPresented, detents: [.medium]) {
                        if selectedOperation != .applyEdits {
                            // Clear the selection if the sheet was dismissed without applying.
                            selectedOperation = .clearSelection
                        }
                    } content: {
                        EditFeatureView(model: model, operationSelection: $selectedOperation)
                    }
            }
        }
        .errorAlert(presentingError: $error)
    }
}

extension ValidateUtilityNetworkTopologyView {
    /// An enumeration representing an operation run on the view model.
    enum ModelOperation: Equatable {
        /// Setup the model.
        case setup
        /// Get the state of the utility network.
        case getState
        /// Run a utility network trace.
        case trace
        /// Validate the utility network topology.
        case validateNetworkTopology
        /// Select a feature on the map at a given screen point.
        case selectFeature(screenPoint: CGPoint? = nil)
        /// Apply the edits to the feature to the service.
        case applyEdits
        /// Clear the selected feature(s).
        case clearSelection
        
        /// The message to display if the operations fails.
        var errorMessage: String {
            switch self {
            case .setup:
                "Initialization failed."
            case .getState:
                "Get state failed."
            case .trace:
                "Trace failed. \nTap 'Get State' to check the updated network state."
            case .selectFeature:
                "Select feature failed."
            case .validateNetworkTopology:
                "Validate network topology failed."
            case .applyEdits:
                "Apply edits failed."
            case .clearSelection:
                ""
            }
        }
    }
}

#Preview {
    NavigationView {
        ValidateUtilityNetworkTopologyView()
    }
}
