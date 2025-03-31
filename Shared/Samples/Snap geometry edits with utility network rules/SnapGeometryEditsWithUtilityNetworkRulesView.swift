// Copyright 2025 Esri
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

struct SnapGeometryEditsWithUtilityNetworkRulesView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// The various states of the sample.
    private enum SampleState: Equatable {
        /// The sample is being set up.
        case setup
        /// The given tap point is being identified.
        case identifying(tapPoint: CGPoint)
        /// The selected feature's geometry is being edited.
        case editing
        /// The feature's edits are being saved to its table.
        case saving
    }
    
    /// The current state of the sample.
    @State private var state = SampleState.setup
    
    /// A Boolean value indicating whether there are edits to be saved.
    @State private var canSave = false
    
    /// A Boolean value indicating whether snap sources list is showing.
    @State private var sourcesListIsPresented = false
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    /// The instruction text indicating the next step in the sample's workflow.
    private var instructionText: String {
        if state == .editing {
            canSave
            ? "Tap the save button to save the edits."
            : "Tap on the map to update the feature's geometry."
        } else {
            model.selectedElement == nil
            ? "Tap the map to select a feature."
            : "Tap the edit button to update the feature."
        }
    }
    
    var body: some View {
        MapViewReader { mapViewProxy in
            MapView(map: model.map, graphicsOverlays: [model.graphicsOverlay])
                .geometryEditor(model.geometryEditor)
                .onSingleTapGesture { screenPoint, _ in
                    state = .identifying(tapPoint: screenPoint)
                }
                .task(id: state) {
                    // Runs the async action related to the current sample state.
                    do {
                        switch state {
                        case .setup:
                            try await model.setUp()
                        case .identifying(let tapPoint):
                            let identifyResults = try await mapViewProxy.identifyLayers(
                                screenPoint: tapPoint,
                                tolerance: 5
                            )
                            try await model.selectFeature(from: identifyResults)
                        case .editing:
                            model.startEditing()
                            
                            for await canUndo in model.geometryEditor.$canUndo {
                                canSave = canUndo
                            }
                        case .saving:
                            try await model.save()
                        }
                    } catch {
                        self.error = error
                    }
                }
                .errorAlert(presentingError: $error)
        }
        .overlay(alignment: .top) {
            VStack(alignment: .trailing, spacing: 0) {
                Text(instructionText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(8)
                    .background(.ultraThinMaterial, ignoresSafeAreaEdges: .horizontal)
                
                if let selectedElement = model.selectedElement {
                    VStack(alignment: .leading) {
                        LabeledContent("Asset Group:", value: selectedElement.assetGroup.name)
                        LabeledContent("Asset Type:", value: selectedElement.assetType.name)
                    }
                    .fixedSize()
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(.rect(cornerRadius: 10))
                    .shadow(radius: 3)
                    .padding(8)
                    .transition(.move(edge: .trailing))
                }
            }
            .animation(.default, value: model.selectedElement == nil)
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button("Cancel", systemImage: "xmark") {
                    model.geometryEditor.stop()
                    model.resetSelection()
                }
                .disabled(model.selectedElement == nil)
                
                Spacer()
                
                Button("Snap Sources") {
                    sourcesListIsPresented = true
                }
                .disabled(model.snapSourceSettings.isEmpty)
                .popover(isPresented: $sourcesListIsPresented) {
                    SnapSourcesList(settings: model.snapSourceSettings)
                        .presentationDetents([.fraction(0.5)])
                        .frame(idealWidth: 320, idealHeight: 390)
                }
                
                Spacer()
                
                if state == .editing {
                    Button("Save", systemImage: "checkmark") {
                        state = .saving
                    }
                    .disabled(!canSave)
                } else {
                    Button("Edit", systemImage: "pencil") {
                        state = .editing
                    }
                    .disabled(model.selectedElement == nil)
                }
            }
        }
    }
}

// MARK: - Helper Views

private extension SnapGeometryEditsWithUtilityNetworkRulesView {
    /// A list for enabling and disabling snap source settings.
    struct SnapSourcesList: View {
        /// The snap source settings to show in the list.
        let settings: [SnapSourceSettings]
        
        /// The action to dismiss the view.
        @Environment(\.dismiss) private var dismiss
        
        /// The display scale of this environment.
        @Environment(\.displayScale) private var displayScale
        
        /// The images for the snap rule behavior legend.
        @State private var ruleBehaviorImages: [SnapRuleBehavior?: Image] = [:]
        
        var body: some View {
            NavigationStack {
                Form {
                    Section {
                        ForEach(Array(settings.enumerated()), id: \.offset) { _, settings in
                            SnapSourceSettingsToggle(
                                settings: settings,
                                image: ruleBehaviorImages[settings.ruleBehavior]
                            )
                        }
                    }
                    
                    Section("Legend") {
                        ForEach(SnapRuleBehavior?.allCases, id: \.self) { behavior in
                            Label {
                                Text(behavior.label)
                            } icon: {
                                ruleBehaviorImages[behavior]
                            }
                            .task(id: displayScale) {
                                // Creates an image from the rule behavior's symbol.
                                let swatch = try? await behavior.symbol.makeSwatch(scale: displayScale)
                                ruleBehaviorImages[behavior] = Image(uiImage: swatch ?? UIImage())
                            }
                        }
                    }
                }
                .navigationTitle("Snap Sources")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            }
        }
    }
    
    /// A toggle for enabling and disabling a given snap source settings.
    struct SnapSourceSettingsToggle: View {
        /// The snap source settings to enable and disable.
        let settings: SnapSourceSettings
        
        /// The image to use in the toggle's label.
        let image: Image?
        
        /// A Boolean value indicating whether the toggle is enabled.
        @State private var isEnabled = false
        
        var body: some View {
            Toggle(isOn: $isEnabled) {
                Label {
                    Text(settings.source.name)
                } icon: {
                    image
                }
            }
            .onChange(of: isEnabled) { newValue in
                settings.isEnabled = newValue
            }
            .onAppear {
                isEnabled = settings.isEnabled
            }
        }
    }
}

// MARK: - Extensions

extension SnapSource {
    /// The name of the snap source.
    var name: String {
        switch self {
        case let graphicsOverlay as GraphicsOverlay:
            graphicsOverlay.id
        case let layerContent as LayerContent:
            layerContent.name
        default:
            "\(self)"
        }
    }
}

extension Optional<SnapRuleBehavior> {
    fileprivate static var allCases: [Self] {
        return [.none, .rulesLimitSnapping, .rulesPreventSnapping]
    }
    
    /// The human-readable label for the snap rule behavior.
    fileprivate var label: String {
        switch self {
        case .rulesLimitSnapping: "Rules Limit Snapping"
        case .rulesPreventSnapping: "Rules Prevent Snapping"
        default: "None"
        }
    }
    
    /// The symbol representing the snap rule behavior.
    var symbol: Symbol {
        switch self {
        case .rulesLimitSnapping:
            SimpleLineSymbol(style: .solid, color: .orange, width: 3)
        case .rulesPreventSnapping:
            SimpleLineSymbol(style: .solid, color: .red, width: 3)
        default:
            SimpleLineSymbol(style: .dash, color: .green, width: 3)
        }
    }
}
