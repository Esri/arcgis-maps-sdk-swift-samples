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

struct DisplayGeometryEditorInformationDuringInteractionView: View {
    /// The view model for the sample.
    @State private var model = Model()
    /// The screen point used to identify a graphic.
    @State private var identifyScreenPoint: CGPoint?

    var body: some View {
        MapViewReader { mapView in
            MapView(map: model.map, graphicsOverlays: [model.graphicsOverlay])
                .geometryEditor(model.geometryEditor)
                .onSingleTapGesture { screenPoint, _ in
                    identifyScreenPoint = screenPoint
                }
                .task(id: identifyScreenPoint) {
                    guard let identifyScreenPoint, !model.isEditing else { return }
                    let result = try? await mapView.identify(
                        on: model.graphicsOverlay,
                        screenPoint: identifyScreenPoint,
                        tolerance: 10
                    )
                    if let graphic = result?.graphics.first {
                        model.startEditing(graphic)
                    }
                }
                .overlay(alignment: .top) {
                    Text(model.informationText)
                        .multilineTextAlignment(.center)
                        .padding(8)
                        .background(.regularMaterial, in: .rect(cornerRadius: 8))
                        .padding()
                }
                .task {
                    await model.observeInteractionPreviews()
                }
                .task {
                    await model.observeCanUndo()
                }
                .task {
                    await model.observeCanRedo()
                }
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button("Discard", systemImage: "xmark") {
                    model.discardEdits()
                }
                .disabled(!model.isEditing)

                Button("Undo", systemImage: "arrow.uturn.backward") {
                    model.geometryEditor.undo()
                }
                .disabled(!model.canUndo)

                Button("Redo", systemImage: "arrow.uturn.forward") {
                    model.geometryEditor.redo()
                }
                .disabled(!model.canRedo)

                Button("Save", systemImage: "checkmark") {
                    model.saveEdits()
                }
                .disabled(!model.isEditing)
            }
        }
    }
}

#Preview {
    NavigationStack {
        DisplayGeometryEditorInformationDuringInteractionView()
    }
}
