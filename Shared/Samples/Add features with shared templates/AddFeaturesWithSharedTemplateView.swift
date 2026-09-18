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
    @StateObject private var model = Model()
    
    /// The geometry currently drawn in the geometry editor.
    @State private var editorGeometry: Geometry?
    
    /// A Boolean value indicating whether the shared templates popover is showing.
    @State private var isShowingTemplates = false
    
    /// The error shown in the error alert.
    @State private var error: (any Error)?
    
    /// A Boolean value indicating whether the current sketch can be completed.
    private var canCompleteDrawing: Bool {
        editorGeometry?.sketchIsValid ?? false
    }
    
    var body: some View {
        MapView(map: model.map)
            .geometryEditor(model.geometryEditor)
            .overlay(alignment: .top) {
                statusOverlay
            }
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Spacer()
                    
                    if model.hasPendingEdits {
                        editButtons
                    } else if model.activeTemplateItem != nil {
                        drawingButtons
                    } else if !model.templateItems.isEmpty {
                        sharedTemplatesButton
                    }
                    
                    Spacer()
                }
            }
            .task {
                do {
                    try await model.setUp()
                } catch {
                    self.error = error
                }
            }
            .task {
                for await geometry in model.geometryEditor.$geometry {
                    editorGeometry = geometry
                }
            }
            .onDisappear {
                model.cancelDrawing()
            }
            .errorAlert(presentingError: $error)
    }

    /// The instructions and progress indicator displayed above the map.
    private var statusOverlay: some View {
        HStack {
            Text(model.status)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            
            if model.isBusy {
                ProgressView()
            }
        }
        .padding(8)
        .background(.regularMaterial, ignoresSafeAreaEdges: .horizontal)
    }
    
    /// The button that presents the shared template picker.
    private var sharedTemplatesButton: some View {
        Button("Shared Templates", systemImage: "square.grid.2x2") {
            isShowingTemplates.toggle()
        }
        .popover(isPresented: $isShowingTemplates) {
            templatePickerContent
                .padding()
                .presentationCompactAdaptation(.popover)
                .frame(idealWidth: 320)
        }
        .disabled(model.isBusy)
    }
    
    /// The available shared templates and their swatches.
    private var templatePickerContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(model.templateItems) { item in
                Button {
                    do {
                        try model.startDrawing(with: item)
                        isShowingTemplates = false
                    } catch {
                        self.error = error
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
                            Text(item.kindName)
                                .font(.caption)
                        }
                        
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(item.template.description)
                .disabled(model.isBusy)
            }
        }
    }
    
    /// The controls for saving or discarding local edits.
    private var editButtons: some View {
        Group {
            Button("Save") {
                Task {
                    do {
                        try await model.saveEdits()
                    } catch {
                        self.error = error
                    }
                }
            }
            
            Button("Undo", role: .destructive) {
                Task {
                    do {
                        try await model.undoEdits()
                    } catch {
                        self.error = error
                    }
                }
            }
        }
        .disabled(model.isBusy)
    }
    
    /// The controls for completing or canceling the current sketch.
    private var drawingButtons: some View {
        Group {
            Button("Complete") {
                Task {
                    do {
                        try await model.completeDrawing()
                    } catch {
                        self.error = error
                    }
                }
            }
            .disabled(!canCompleteDrawing)
            
            Button("Cancel", role: .cancel) {
                model.cancelDrawing()
            }
        }
        .disabled(model.isBusy)
    }
}

#Preview {
    NavigationStack {
        AddFeaturesWithSharedTemplateView()
    }
}
