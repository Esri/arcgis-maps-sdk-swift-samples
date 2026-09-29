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
    @State private var templatesAreVisible = false

    /// The requested editing operation, used as the editing task's identity.
    @State private var pendingAction: EditingAction?
    
    /// An error from loading templates, starting a sketch, or editing features
    /// that is presented in an alert. Task cancellation is not shown as an error.
    @State private var presentedError: (any Error)?
    
    var body: some View {
        MapView(map: model.map)
            .geometryEditor(model.geometryEditor)
            .overlay(alignment: .top) {
                statusOverlay
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
                } catch {
                    guard !Task.isCancelled,
                          !(error is CancellationError) else { return }
                    self.presentedError = error
                }
            }
            .task {
                for await geometry in model.geometryEditor.$geometry {
                    canCompleteDrawing = geometry?.sketchIsValid ?? false
                }
            }
            .task(id: model.statusResetID) {
                guard let id = model.statusResetID else { return }
                await model.resetStatus(afterDelayFor: id)
            }
            // Keep this task on the map view, not the conditional buttons.
            .task(id: pendingAction) {
                guard let action = pendingAction else { return }
                defer { pendingAction = nil }

                do {
                    try Task.checkCancellation()
                    switch action {
                    case .save:
                        try await model.saveEdits()
                    case .undo:
                        try await model.undoEdits()
                    case .complete:
                        try await model.completeDrawing()
                    }
                } catch {
                    // Cancellation does not roll back submitted service edits.
                    guard !Task.isCancelled,
                          !(error is CancellationError) else { return }
                    self.presentedError = error
                }
            }
            .onDisappear {
                // Do not replay a queued action when the view reappears.
                pendingAction = nil
                if model.geometryEditor.isStarted {
                    model.cancelDrawing()
                }
            }
            .errorAlert(presentingError: $presentedError)
    }

    /// The instructions and progress indicator displayed above the map.
    private var statusOverlay: some View {
        HStack {
            VStack {
                Text(model.status)
                if let instruction = model.nextStepInstruction {
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
    
    /// The button that presents the shared template picker.
    private var sharedTemplatesButton: some View {
        Button("Shared Templates", systemImage: "square.grid.2x2") {
            templatesAreVisible = true
        }
        .popover(isPresented: $templatesAreVisible) {
            templatePickerContent
                .padding()
                .presentationCompactAdaptation(.popover)
                .frame(idealWidth: 320)
        }
        .disabled(model.operationIsInProgress || pendingAction != nil)
    }
    
    /// The available shared templates and their swatches.
    private var templatePickerContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(model.templateItems) { item in
                Button {
                    do {
                        try model.startDrawing(with: item)
                        templatesAreVisible = false
                    } catch {
                        self.presentedError = error
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(uiImage: item.swatch)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 36, height: 36)
                        
                        VStack(alignment: .leading) {
                            Text(item.template.name)
                                .fontWeight(.semibold)
                            Text(item.kindLabel)
                                .font(.caption)
                        }
                        
                        Spacer()
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .help(item.template.description)
                .disabled(model.operationIsInProgress || pendingAction != nil)
            }
        }
    }
    
    /// The controls for saving or discarding local edits.
    private var editButtons: some View {
        Group {
            Button("Save") {
                pendingAction = .save
            }
            
            Spacer()
            
            Button("Undo", role: .destructive) {
                pendingAction = .undo
            }
        }
        .disabled(model.operationIsInProgress || pendingAction != nil)
    }
    
    /// The controls for completing or canceling the current sketch.
    private var drawingButtons: some View {
        Group {
            Button("Complete") {
                pendingAction = .complete
            }
            .disabled(!canCompleteDrawing)
            
            Spacer()
            
            Button("Cancel", role: .cancel) {
                model.cancelDrawing()
            }
        }
        .disabled(model.operationIsInProgress || pendingAction != nil)
    }
}

private extension AddFeaturesWithSharedTemplateView {
    /// An editing operation requested by a toolbar button.
    enum EditingAction: Equatable {
        case save
        case undo
        case complete
    }
}

#Preview {
    NavigationStack {
        AddFeaturesWithSharedTemplateView()
    }
}
