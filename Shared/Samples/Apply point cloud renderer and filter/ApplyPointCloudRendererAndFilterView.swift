// Copyright 2026 Esri
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

struct ApplyPointCloudRendererAndFilterView: View {
    /// The model that stores the scene, layer, and renderers.
    @State private var model = Model()
    
    /// A Boolean value indicating whether the settings are visible.
    @State private var settingsAreVisible = false
    
    /// A Boolean value indicating whether the point cloud layer is loading.
    @State private var isLoading = true
    
    /// An error encountered while loading or displaying the scene.
    @State private var error: (any Error)?
    
    var body: some View {
        // Live point cloud filter changes require a local scene view.
        LocalSceneView(scene: model.scene)
            .onGeoModelErrorChanged { error in
                if let error {
                    self.error = error
                }
            }
            .onLayerViewStateChanged { layer, viewState in
                if layer === model.pointCloudLayer,
                   model.pointCloudLayer.loadStatus == .loaded,
                   viewState.status.contains(.error),
                   let error = viewState.error {
                    self.error = error
                }
            }
            .overlay {
                if isLoading {
                    ProgressView("Loading point cloud")
                        .padding()
                        .background(
                            .regularMaterial,
                            in: .rect(cornerRadius: 10)
                        )
                }
            }
            .task {
                for await status in model.pointCloudLayer.$loadStatus {
                    guard !Task.isCancelled else { return }
                    isLoading = status == .notLoaded || status == .loading
                    if status == .failed {
                        error = model.pointCloudLayer.loadError
                    }
                }
            }
            .errorAlert(presentingError: $error)
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button("Settings", systemImage: "gear") {
                        settingsAreVisible = true
                    }
                    .disabled(isLoading || model.pointCloudLayer.loadStatus != .loaded)
                    .popover(isPresented: $settingsAreVisible) {
                        NavigationStack {
                            SettingsView(model: model)
                        }
                        .frame(idealWidth: 400, idealHeight: 600)
                        .presentationCompactAdaptation(.popover)
                    }
                }
            }
    }
}

private extension ApplyPointCloudRendererAndFilterView {
    /// The settings for rendering and independently filtering the point cloud.
    struct SettingsView: View {
        /// The action to dismiss the settings.
        @Environment(\.dismiss) private var dismiss
        
        /// The model whose settings are edited by the controls.
        @Bindable var model: Model
        
        var body: some View {
            Form {
                Section("Renderer") {
                    Picker("Type", selection: $model.rendererKind) {
                        ForEach(RendererKind.allCases, id: \.self) { kind in
                            Text(LocalizedStringKey(kind.label))
                        }
                    }
                    LabeledContent("Point Size Scale") {
                        Text("\(model.scaleFactor, format: .number.precision(.fractionLength(1)))")
                    }
                    Slider(value: $model.scaleFactor, in: 0.1...5, step: 0.1) {
                        Text("Point Size Scale")
                    } minimumValueLabel: {
                        Text("0.1")
                    } maximumValueLabel: {
                        Text("5")
                    }
                }
                
                Section {
                    Picker("Mode", selection: $model.classificationMode) {
                        Text("Include").tag(PointCloudValueFilter.Mode.include)
                        Text("Exclude").tag(PointCloudValueFilter.Mode.exclude)
                    }
                    ForEach(
                        Classification.allCases,
                        id: \.self
                    ) { classification in
                        Toggle(classification.label, isOn: Binding(
                            get: {
                                model.selectedClassifications
                                    .contains(classification)
                            },
                            set: {
                                model.setClassification(
                                    classification,
                                    isSelected: $0
                                )
                            }
                        ))
                    }
                    Button(
                        "Clear Classification Filter",
                        action: model.clearClassificationFilter
                    )
                    .disabled(!model.classificationFilterIsActive)
                } header: {
                    Text("Classification Filter")
                } footer: {
                    Text("""
                        With no classification filter, all Include switches \
                        are on and all Exclude switches are off. Changing \
                        modes inverts the selections for the listed codes. \
                        Once applied, Include with no selections hides all \
                        points; Exclude with no selections does not restrict \
                        classifications. Clear removes this filter. Other \
                        filters still apply.
                        """)
                }
                
                Section {
                    ForEach(ReturnOptions.types, id: \.self) { returnType in
                        Toggle(
                            ReturnOptions.label(for: returnType),
                            isOn: Binding(
                                get: {
                                    model.selectedReturns.contains(returnType)
                                },
                                set: {
                                    model.setReturnType(
                                        returnType,
                                        isSelected: $0
                                    )
                                }
                            )
                        )
                    }
                } header: {
                    Text("Return Filter")
                } footer: {
                    Text("""
                        With no return types selected, this filter is removed. \
                        Other filters still apply. Last includes both Last of \
                        Many and Single. Selecting either alongside Last does \
                        not include additional points.
                        """)
                }
                
                Section("Scan Direction Filter") {
                    Picker("Flag Bit 6", selection: $model.scanDirection) {
                        ForEach(
                            ScanDirection.allCases,
                            id: \.self
                        ) { direction in
                            Text(LocalizedStringKey(direction.label))
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ApplyPointCloudRendererAndFilterView()
    }
}
