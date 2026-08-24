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
    
    /// The error shown in the error alert.
    @State private var error: (any Error)?
    
    /// The display scale used when creating template swatches.
    @Environment(\.displayScale) private var displayScale
    
    var body: some View {
        MapView(map: model.map)
            .geometryEditor(model.geometryEditor)
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(model.status)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        if model.isBusy {
                            Spacer()
                            ProgressView()
                        }
                    }
                    
                    if model.activeTemplateItem == nil,
                       !model.hasPendingEdits,
                       !model.templateItems.isEmpty {
                        ForEach(model.templateItems) { item in
                            Button {
                                do {
                                    try model.startDrawing(with: item)
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
                .padding()
                .frame(maxWidth: 300)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                .padding()
            }
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Spacer()
                    
                    if model.hasPendingEdits {
                        Button("Save") {
                            Task {
                                do {
                                    try await model.saveEdits()
                                } catch {
                                    self.error = error
                                }
                            }
                        }
                        .disabled(model.isBusy)
                        
                        Button("Undo", role: .destructive) {
                            Task {
                                do {
                                    try await model.undoEdits()
                                } catch {
                                    self.error = error
                                }
                            }
                        }
                        .disabled(model.isBusy)
                    } else if model.activeTemplateItem != nil {
                        Button("Complete") {
                            Task {
                                do {
                                    try await model.completeDrawing()
                                } catch {
                                    self.error = error
                                }
                            }
                        }
                        .disabled(!(editorGeometry?.sketchIsValid ?? false) || model.isBusy)
                        
                        Button("Cancel", role: .cancel) {
                            model.cancelDrawing()
                        }
                        .disabled(model.isBusy)
                    }
                    
                    Spacer()
                }
            }
            .task {
                do {
                    try await model.setUp(displayScale: displayScale)
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
}

#Preview {
    NavigationStack {
        AddFeaturesWithSharedTemplateView()
    }
}
