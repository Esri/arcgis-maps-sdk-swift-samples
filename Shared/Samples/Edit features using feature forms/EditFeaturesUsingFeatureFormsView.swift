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
import ArcGISToolkit
import SwiftUI

struct EditFeaturesUsingFeatureFormsView: View {
    /// The map that contains the features for editing.
    @State private var map = Map(
        item: PortalItem(
            portal: .arcGISOnline(connection: .anonymous),
            id: .featureFormPlacesWebMap
        )
    )
    
    /// The feature form for the selected feature.
    @State private var featureForm: FeatureForm?
    
    /// The point on the screen where the user tapped.
    @State private var tapPoint: CGPoint?
    
    /// A Boolean value indicating whether the feature form panel is presented.
    @State private var isShowingFeatureForm = false
    
    /// A Boolean value indicating whether the discard edits alert is presented.
    @State private var isShowingDiscardEditsAlert = false
    
    /// A Boolean value indicating whether the feature form has any validation errors.
    @State private var hasValidationErrors = false
    
    /// A Boolean value indicating whether the feature form edits are being applied.
    @State private var isApplyingEdits = false
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    /// The text explaining the next step in the sample's workflow.
    private var instructionText: String {
        if !isShowingFeatureForm {
            "Tap on a feature to edit."
        } else if hasValidationErrors {
            "Fix the errors to apply the edits."
        } else if isApplyingEdits {
            "Applying edits..."
        } else {
            "Use the form to edit the feature's attributes."
        }
    }
    
    /// The feature layer on the map.
    private var featureLayer: FeatureLayer {
        map.operationalLayers.first as! FeatureLayer
    }
    
    var body: some View {
        MapViewReader { mapViewProxy in
            MapView(map: map)
                .onSingleTapGesture { screenPoint, _ in
                    if isShowingFeatureForm {
                        isShowingDiscardEditsAlert = true
                    } else {
                        tapPoint = screenPoint
                    }
                }
                .task(id: tapPoint) {
                    // Identifies the feature at the tapped point and creates a feature form from it.
                    guard let tapPoint else { return }
                    
                    do {
                        let identifyLayerResult = try await mapViewProxy.identify(
                            on: featureLayer,
                            screenPoint: tapPoint,
                            tolerance: 10
                        )
                        if let feature = identifyLayerResult.geoElements.first as? ArcGISFeature {
                            featureLayer.selectFeature(feature)
                            featureForm = FeatureForm(feature: feature)
                            isShowingFeatureForm = true
                        }
                    } catch {
                        self.error = error
                    }
                }
                .overlay(alignment: .top) {
                    Text(instructionText)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(8)
                        .background(.regularMaterial, ignoresSafeAreaEdges: .horizontal)
                }
                .floatingPanel(isPresented: $isShowingFeatureForm) { [featureForm] in
                    if let featureForm {
                        VStack {
                            featureFormToolbar
                            
                            // Displays the feature form using the toolkit component.
                            FeatureFormView(featureForm: featureForm)
                                .padding(.horizontal)
                                .task {
                                    for await validationErrors in featureForm.$validationErrors {
                                        hasValidationErrors = !validationErrors.isEmpty
                                    }
                                }
                        }
                    }
                }
                .alert("Discard Edits", isPresented: $isShowingDiscardEditsAlert) {
                    Button("Cancel", role: .cancel) {}
                    Button("Discard", role: .destructive) {
                        featureForm?.discardEdits()
                        endEditing()
                    }
                } message: {
                    Text("Any changes made within the form will be lost.")
                }
                .errorAlert(presentingError: $error)
        }
    }
    
    /// The toolbar for the feature form panel.
    private var featureFormToolbar: some View {
        HStack {
            Button("Discard Edits", systemImage: "x.circle", role: .destructive) {
                isShowingDiscardEditsAlert = true
            }
            
            Spacer()
            
            Text("Edit Feature")
            
            Spacer()
            
            Button("Done", systemImage: "checkmark") {
                isApplyingEdits = true
            }
            .disabled(hasValidationErrors)
            .task(id: isApplyingEdits) {
                guard isApplyingEdits else { return }
                defer { isApplyingEdits = false }
                
                do {
                    try await applyEdits()
                    endEditing()
                } catch {
                    self.error = error
                }
            }
        }
        .fontWeight(.medium)
        .labelStyle(.iconOnly)
        .padding()
    }
    
    /// Closes the feature form panel and resets the feature selection.
    private func endEditing() {
        isShowingFeatureForm = false
        featureLayer.clearSelection()
    }
    
    /// Applies the edits made in the feature form to the feature service.
    private func applyEdits() async throws {
        guard let featureForm else { return }
        
        // Saves the feature form edits to the database.
        try await featureForm.finishEditing()
        
        guard let serviceFeatureTable = featureForm.feature.table as? ServiceFeatureTable else {
            return
        }
        
        // Applies the edits to the feature service using either the database or feature table.
        if let serviceGeodatabase = serviceFeatureTable.serviceGeodatabase,
           let serviceInfo = serviceGeodatabase.serviceInfo,
           serviceInfo.canUseServiceGeodatabaseApplyEdits {
            _ = try await serviceGeodatabase.applyEdits()
        } else {
            _ = try await serviceFeatureTable.applyEdits()
        }
    }
}

private extension PortalItem.ID {
    /// The ID to the "Feature Form Places" web map portal item on ArcGIS Online.
    static var featureFormPlacesWebMap: Self { .init("516e4d6aeb4c495c87c41e11274c767f")! }
}

#Preview {
    EditFeaturesUsingFeatureFormsView()
}
