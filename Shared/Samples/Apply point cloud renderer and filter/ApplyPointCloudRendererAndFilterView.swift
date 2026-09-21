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

    /// The loading error shown with a retry action, separate from rendering
    /// errors.
    @State private var loadError: (any Error)?

    /// The loading task's identity. Incrementing it starts another attempt
    /// through the view's `.task(id:)` modifier.
    @State private var loadAttempt = 0

    /// The rendering error shown in the error alert.
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
                } else if let loadError {
                    VStack(spacing: 12) {
                        Label(
                            "Unable to Load Point Cloud",
                            systemImage: "exclamationmark.triangle"
                        )
                        .font(.headline)
                        Text(loadError.localizedDescription)
                            .font(.subheadline)
                        Button("Retry") {
                            isLoading = true
                            loadAttempt += 1
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: 320)
                    .background(.regularMaterial, in: .rect(cornerRadius: 10))
                    .padding()
                }
            }
            .task(id: loadAttempt) {
                isLoading = true
                loadError = nil
                defer { isLoading = false }
                do {
                    // Retry failed loads on the same layer instance.
                    if model.pointCloudLayer.loadStatus == .failed {
                        try await model.pointCloudLayer.retryLoad()
                    } else {
                        try await model.pointCloudLayer.load()
                    }
                } catch {
                    // Leaving the sample should not present a loading failure.
                    guard !Task.isCancelled,
                          !(error is CancellationError) else { return }
                    loadError = error
                }
            }
            .errorAlert(presentingError: $error)
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button("Settings", systemImage: "gear") {
                        settingsAreVisible = true
                    }
                    .disabled(isLoading || loadError != nil)
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
                            Text(kind.rawValue)
                        }
                    }
                    LabeledContent(
                        "Point Size",
                        value: model.scaleFactor,
                        format: .number.precision(.fractionLength(1))
                    )
                    Slider(value: $model.scaleFactor, in: 0.1...5, step: 0.1) {
                        Text("Point Size")
                    } minimumValueLabel: {
                        Text("0.1")
                    } maximumValueLabel: {
                        Text("5")
                    }
                }

                Section {
                    LabeledContent(
                        "Status",
                        value: model.classificationFilterIsActive
                            ? "Applied" : "Not Applied"
                    )
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
                        Once applied, Include with no selections hides all \
                        points; Exclude with no selections shows all points. \
                        Clear removes this filter.
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
                    Button(
                        "Clear Return Filter",
                        action: model.clearReturnFilter
                    )
                } header: {
                    Text("Return Filter")
                } footer: {
                    Text("No selected return types shows all points.")
                }

                Section("Scan Direction Filter") {
                    Picker("Flag Bit 6", selection: $model.scanDirection) {
                        ForEach(
                            ScanDirection.allCases,
                            id: \.self
                        ) { direction in
                            Text(direction.rawValue)
                        }
                    }
                    Button("Clear Scan Direction Filter") {
                        model.scanDirection = .any
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
