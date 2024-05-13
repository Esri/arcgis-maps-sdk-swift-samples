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

struct EditAndSyncFeaturesWithFeatureServiceView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// The asynchronous action currently being preformed.
    @State private var selectedAction: AsyncAction? = .setUpMap
    
    /// The text describing the status of the sample.
    @State private var statusText = ""
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    var body: some View {
        GeometryReader { geometryProxy in
            MapViewReader { mapViewProxy in
                MapView(map: model.map)
                    .interactionModes(model.geodatabase != nil ? [] : [.all])
                    .onSingleTapGesture { screenPoint, mapPoint in
                        guard model.geodatabase != nil else { return }
                        
                        selectedAction = model.selectedFeature == nil
                        ? .selectFeature(screenPoint: screenPoint)
                        : .moveSelectedFeature(mapPoint: mapPoint)
                    }
                    .task(id: selectedAction) {
                        // Performs the selected action.
                        guard let action = selectedAction else { return }
                        
                        do {
                            switch action {
                            case .setUpMap:
                                statusText = "Loading feature layers…"
                                try await model.setUpMap()
                                statusText = action.completionMessage
                            case .generateGeodatabase:
                                // Creates an envelope from the area of interest.
                                let viewRect = geometryProxy.frame(in: .local).inset(
                                    by: UIEdgeInsets(
                                        top: 20,
                                        left: geometryProxy.safeAreaInsets.leading + 20,
                                        bottom: 44,
                                        right: -geometryProxy.safeAreaInsets.trailing + 20
                                    )
                                )
                                guard let extent = mapViewProxy.envelope(
                                    fromViewRect: viewRect
                                ) else { return }
                                
                                // Generates the geodatabase using the envelope.
                                try await model.generateGeodatabase(extent: extent)
                                statusText = action.completionMessage
                            case .selectFeature(let screenPoint):
                                // Identifies and selects a feature at the tapped screen point.
                                let identifyLayerResults = try await mapViewProxy.identifyLayers(
                                    screenPoint: screenPoint,
                                    tolerance: 22,
                                    maximumResultsPerLayer: 1
                                )
                                
                                model.selectFeature(identifyLayerResults: identifyLayerResults)
                                if model.selectedFeature != nil {
                                    statusText = action.completionMessage
                                }
                            case .moveSelectedFeature(mapPoint: let mapPoint):
                                try await model.moveSelectedFeature(point: mapPoint)
                                statusText = action.completionMessage
                            case .sync:
                                try await model.syncGeodatabase()
                                statusText = action.completionMessage
                            case .cancelJob:
                                await model.cancelJob()
                                statusText = action.completionMessage
                            case .reset:
                                await model.reset()
                                await mapViewProxy.setViewpoint(model.map.initialViewpoint!)
                                selectedAction = .setUpMap
                                return
                            }
                        } catch {
                            self.error = error
                        }
                        
                        selectedAction = nil
                    }
                    .errorAlert(presentingError: $error)
            }
        }
        .overlay(alignment: .top) {
            VStack {
                Text(statusText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(8)
                    .background(.regularMaterial, ignoresSafeAreaEdges: .horizontal)
                
                Rectangle()
                    .stroke(.red, lineWidth: 2)
                    .padding(EdgeInsets(top: 20, leading: 20, bottom: 44, trailing: 20))
            }
        }
        .disabled(selectedAction != nil)
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button("Reset") {
                    selectedAction = .reset
                }
                .disabled(model.geodatabase == nil)
                
                Button(model.geodatabase == nil ? "Generate Geodatabase" : "Sync Geodatabase") {
                    selectedAction = model.geodatabase == nil ? .generateGeodatabase : .sync
                }
                .disabled(model.geodatabase != nil && !(model.geodatabase?.hasLocalEdits ?? false))
            }
        }
        .overlay(alignment: .center) {
            // Shows a progress view when there is a job currently running.
            if let progress = model.currentJob?.progress {
                VStack {
                    Text(selectedAction == .generateGeodatabase
                         ? "Creating geodatabase…"
                         : "Syncing geodatabase…"
                    )
                    .padding(.bottom)
                    
                    ProgressView(progress)
                        .frame(maxWidth: 180)
                    
                    Button("Cancel") {
                        selectedAction = .cancelJob
                    }
                    .disabled(selectedAction == .cancelJob)
                }
                .padding()
                .background(.ultraThickMaterial)
                .cornerRadius(10)
                .shadow(radius: 50)
            }
        }
        .onDisappear {
            // Cancels any running jobs when the sample is exited.
            Task { await model.cancelJob() }
        }
    }
}

/// An asynchronous action associated with the sample.
private enum AsyncAction: Equatable {
    /// Sets up the map for the sample.
    case setUpMap
    /// Generates a geodatabase from the current area of interest.
    case generateGeodatabase
    /// Identifies and selects a feature identified at a given screen point.
    case selectFeature(screenPoint: CGPoint)
    /// Moves the selected feature to a given map point.
    case moveSelectedFeature(mapPoint: Point)
    /// Synchronizes the geodatabase and the feature service.
    case sync
    /// Cancels the current job.
    case cancelJob
    /// Resets the sample.
    case reset
    
    /// The message to display when the action successfully completes.
    var completionMessage: String {
        switch self {
        case .setUpMap: "Tap the generate button to take the area offline."
        case .generateGeodatabase: "Tap on a feature to edit."
        case .selectFeature: "Tap on the map to move the feature."
        case .moveSelectedFeature: "Tap the sync button to sync the edits."
        case .sync: "Geodatabase sync successful."
        case .cancelJob: "Job canceled."
        default: "Unknown"
        }
    }
}
