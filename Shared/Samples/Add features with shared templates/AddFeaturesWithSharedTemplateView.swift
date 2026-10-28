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

struct AddFeaturesWithSharedTemplateView: View {
    /// The view model for the sample.
    @State private var model = Model()
    
    /// The observed sketch validity. The geometry editor's change stream
    /// updates this state so SwiftUI refreshes the Complete button.
    @State private var canCompleteDrawing = false
    
    /// Whether the shared templates popover is showing.
    @State private var templatePickerIsPresented = false
    
    /// The requested editing operation, used as the editing task's identity.
    @State private var pendingGeodatabaseAction: EditingAction?
    
    /// An error from loading templates, starting a sketch, or editing features
    /// that is presented in an alert. Task cancellation is not shown as an error.
    @State private var presentedError: (any Error)?
    
    var body: some View {
        MapView(map: model.map)
            .geometryEditor(model.geometryEditor)
            .overlay(alignment: .top) {
                if !templatesAreUnavailable {
                    statusOverlay
                }
            }
            .overlay {
                if templatesAreUnavailable {
                    ContentUnavailableView(
                        "No Templates",
                        systemImage: "square.grid.2x2",
                        description: Text(
                            "This map has no preset or group shared templates."
                        )
                    )
                    .background(.regularMaterial)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    if model.hasPendingEdits {
                        editButtons
                    } else if model.activeTemplateItem != nil {
                        drawingButtons
                    } else if !model.templateItems.isEmpty {
                        sharedTemplatesButton
                    }
                }
            }
            .task {
                do {
                    try await model.setUp()
                } catch is CancellationError {
                    // Do nothing.
                } catch {
                    self.presentedError = error
                }
            }
            .task {
                for await geometry in model.geometryEditor.$geometry {
                    canCompleteDrawing = geometry?.sketchIsValid ?? false
                }
            }
            .task(id: model.stateResetID) {
                guard let id = model.stateResetID else { return }
                await model.resetStateAfterDelay(for: id)
            }
            // Keep this task on the map view, not the conditional buttons.
            .task(id: pendingGeodatabaseAction) {
                guard let action = pendingGeodatabaseAction else { return }
                defer { pendingGeodatabaseAction = nil }
                
                do {
                    switch action {
                    case .save:
                        try await model.saveEdits()
                    case .undo:
                        try await model.undoEdits()
                    case .complete:
                        try await model.completeDrawing()
                    }
                } catch is CancellationError {
                    // Cancellation does not roll back submitted service edits.
                } catch {
                    self.presentedError = error
                }
            }
            .onDisappear {
                // Do not replay a queued action when the view reappears.
                pendingGeodatabaseAction = nil
                if model.geometryEditor.isStarted {
                    model.cancelDrawing()
                }
            }
            .errorAlert(presentingError: $presentedError)
    }
    
    /// Whether loading succeeded without any supported templates.
    private var templatesAreUnavailable: Bool {
        model.state == .ready && model.templateItems.isEmpty
    }
    
    /// The instructions and progress indicator displayed above the map.
    private var statusOverlay: some View {
        HStack {
            VStack {
                Text(statusText)
                if let instruction = nextStepInstruction {
                    Text(instruction)
                }
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            
            if model.operationIsInProgress {
                ProgressView()
            }
        }
        .padding(8)
        .background(.regularMaterial, ignoresSafeAreaEdges: .horizontal)
    }
    
    /// The localized presentation of the current workflow state.
    private var statusText: LocalizedStringKey {
        switch model.state {
        case .creatingFeatures:
            "Creating features…"
        case .creationFailed:
            "Unable to create or add features."
        case .drawingCanceled:
            "Draw canceled."
        case .drawingLine:
            "Sketch a line, then tap Complete or Cancel."
        case .drawingPoint:
            "Place a point, then tap Complete or Cancel."
        case .editsSaved:
            "Edits saved."
        case .editsUndone:
            "Edits undone."
        case .featuresAdded:
            "Features added."
        case .invalidGeometry:
            "Draw a valid geometry, then tap Complete or Cancel."
        case .loading:
            "Loading shared templates…"
        case .loadingFailed:
            "Unable to load templates."
        case .ready:
            templateInstruction
        case .savingEdits:
            "Saving edits…"
        case .savingFailed:
            "Unable to save edits."
        case .undoFailed:
            "Unable to undo edits."
        case .undoingEdits:
            "Undoing local edits…"
        }
    }
    
    /// The next action after an editing operation, based on current edits.
    private var nextStepInstruction: LocalizedStringKey? {
        switch model.state {
        case .creationFailed, .editsSaved, .editsUndone, .featuresAdded,
                .savingFailed, .undoFailed:
            model.hasPendingEdits ? "Save or undo edits." : templateInstruction
        default:
            nil
        }
    }
    
    /// The instruction shown while the template picker is available.
    private var templateInstruction: LocalizedStringKey {
        "Open Shared Templates and select a template to create features."
    }
    
    /// A localized label for a shared template kind.
    /// - Parameter kind: The kind of shared template to describe.
    /// - Returns: The template kind's localized string key.
    private func kindLabel(for kind: SharedTemplate.Kind) -> LocalizedStringKey {
        switch kind {
        case .feature: "Feature"
        case .group: "Group"
        case .preset: "Preset"
        @unknown default: "Unknown"
        }
    }
    
    /// The button that presents the shared template picker.
    private var sharedTemplatesButton: some View {
        Button("Shared Templates", systemImage: "square.grid.2x2") {
            templatePickerIsPresented = true
        }
        .popover(isPresented: $templatePickerIsPresented) {
            templatePickerContent
                .padding()
                .presentationCompactAdaptation(.popover)
                .frame(idealWidth: 320)
        }
        .disabled(model.operationIsInProgress || pendingGeodatabaseAction != nil)
    }
    
    /// The available shared templates and their swatches.
    private var templatePickerContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(model.templateItems) { item in
                Button {
                    do {
                        try model.startDrawing(with: item)
                        templatePickerIsPresented = false
                    } catch {
                        self.presentedError = error
                    }
                } label: {
                    HStack(spacing: 8) {
                        TemplateSwatch(item: item)
                        
                        VStack(alignment: .leading) {
                            Text(item.template.name)
                                .fontWeight(.semibold)
                            Text(kindLabel(for: item.template.kind))
                                .font(.caption)
                        }
                        
                        Spacer()
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .help(item.template.description)
                .disabled(model.operationIsInProgress || pendingGeodatabaseAction != nil)
            }
        }
    }
    
    /// The controls for saving or discarding local edits.
    private var editButtons: some View {
        Group {
            Button("Save") {
                pendingGeodatabaseAction = .save
            }
            
            Spacer()
            
            Button("Undo") {
                pendingGeodatabaseAction = .undo
            }
        }
        .disabled(model.operationIsInProgress || pendingGeodatabaseAction != nil)
    }
    
    /// The controls for completing or canceling the current sketch.
    private var drawingButtons: some View {
        Group {
            if #available(iOS 26, *) {
                Button(role: .cancel) {
                    model.cancelDrawing()
                }
            } else {
                Button("Cancel", systemImage: "xmark") {
                    model.cancelDrawing()
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
            
            if #available(iOS 26, *) {
                Button(role: .confirm) {
                    pendingGeodatabaseAction = .complete
                }
                .disabled(!canCompleteDrawing)
            } else {
                Button("Done", systemImage: "checkmark") {
                    pendingGeodatabaseAction = .complete
                }
                .disabled(!canCompleteDrawing)
                .buttonStyle(.plain)
            }
        }
        .disabled(model.operationIsInProgress || pendingGeodatabaseAction != nil)
    }
}

private extension AddFeaturesWithSharedTemplateView {
    /// A template's swatch, rendered when its picker row appears.
    struct TemplateSwatch: View {
        /// The template and target layer used to render the swatch.
        let item: Model.TemplateItem
        
        /// The rendered swatch for the template.
        @State private var swatch: UIImage?
        
        var body: some View {
            let image = if let swatch {
                Image(uiImage: swatch)
            } else {
                Image(systemName: "plus.square")
            }
            image
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
                .accessibilityHidden(true)
                .task(id: item.id) {
                    swatch = nil
                    // A missing swatch should not prevent template selection.
                    guard let swatch = try? await item.template
                        .makeSwatch(layerID: item.layerID) else {
                        return
                    }
                    self.swatch = swatch
                }
        }
    }
    
    /// An editing operation requested by a toolbar button.
    enum EditingAction: Equatable {
        case save
        case undo
        case complete
    }
}

extension AddFeaturesWithSharedTemplateView.Model.SampleError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .sharedTemplateSourceNotFound:
            "The map does not contain a shared template source."
        case .unsupportedConstructionTool:
            "The template's default construction tool is not supported by this sample."
        }
    }
}

#Preview {
    NavigationStack {
        AddFeaturesWithSharedTemplateView()
    }
}
