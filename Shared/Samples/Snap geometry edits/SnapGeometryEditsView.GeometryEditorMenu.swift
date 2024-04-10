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

extension SnapGeometryEditsView {
    /// A view that provides a menu for geometry editor functionality.
    struct GeometryEditorMenu: View {
        /// The model for the sample.
        @ObservedObject var model: GeometryEditorModel
        
        var body: some View {
            Menu {
                if !model.isStarted {
                    // If the geometry editor is not started, show the main menu.
                    mainMenuContent
                } else {
                    // If the geometry editor is started, show the edit menu.
                    editMenuContent
                }
            } label: {
                Label("Geometry Editor", systemImage: "pencil.tip.crop.circle")
            }
        }
        
        /// A Boolean value indicating whether the selection can be deleted.
        ///
        /// In some instances deleting the selection may be invalid.
        /// One example would be the mid vertex of a line.
        private var deleteButtonIsDisabled: Bool {
            guard let selection = model.selection else { return true }
            return !selection.canBeDeleted
        }
        
        /// The content of the main menu.
        private var mainMenuContent: some View {
            VStack {
                Button {
                    model.startEditing(with: VertexTool(), geometryType: Point.self)
                } label: {
                    Label("New Point", systemImage: "smallcircle.filled.circle")
                }
                
                Button {
                    model.startEditing(with: VertexTool(), geometryType: Polyline.self)
                } label: {
                    Label("New Line", systemImage: "line.diagonal")
                }
                
                Button {
                    model.startEditing(with: VertexTool(), geometryType: Polygon.self)
                } label: {
                    Label("New Area", systemImage: "skew")
                }
                
                Button {
                    model.startEditing(with: VertexTool(), geometryType: Multipoint.self)
                } label: {
                    Label("New Multipoint", systemImage: "hand.point.up.braille")
                }
                
                Button {
                    model.startEditing(with: FreehandTool(), geometryType: Polyline.self)
                } label: {
                    Label("New Freehand Line", systemImage: "scribble")
                }
                
                Button {
                    model.startEditing(with: FreehandTool(), geometryType: Polygon.self)
                } label: {
                    Label("New Freehand Area", systemImage: "lasso")
                }
                
                Menu("Shapes") {
                    Button {
                        model.startEditing(with: ShapeTool(kind: .arrow), geometryType: Polyline.self)
                    } label: {
                        Label("New Line Arrow", systemImage: "arrowshape.right")
                    }
                    
                    Button {
                        model.startEditing(with: ShapeTool(kind: .arrow), geometryType: Polygon.self)
                    } label: {
                        Label("New Polygon Arrow", systemImage: "arrowshape.right.fill")
                    }
                    
                    Button {
                        model.startEditing(with: ShapeTool(kind: .rectangle), geometryType: Polyline.self)
                    } label: {
                        Label("New Line Rectangle", systemImage: "rectangle")
                    }
                    
                    Button {
                        model.startEditing(with: ShapeTool(kind: .rectangle), geometryType: Polygon.self)
                    } label: {
                        Label("New Polygon Rectangle", systemImage: "rectangle.fill")
                    }
                    
                    Button {
                        model.startEditing(with: ShapeTool(kind: .ellipse), geometryType: Polyline.self)
                    } label: {
                        Label("New Line Ellipse", systemImage: "circle")
                    }
                    
                    Button {
                        model.startEditing(with: ShapeTool(kind: .ellipse), geometryType: Polygon.self)
                    } label: {
                        Label("New Polygon Ellipse", systemImage: "circle.fill")
                    }
                    
                    Button {
                        model.startEditing(with: ShapeTool(kind: .triangle), geometryType: Polyline.self)
                    } label: {
                        Label("New Line Triangle", systemImage: "triangle")
                    }
                    
                    Button {
                        model.startEditing(with: ShapeTool(kind: .triangle), geometryType: Polygon.self)
                    } label: {
                        Label("New Polygon Triangle", systemImage: "triangle.fill")
                    }
                }
                
                Divider()
                
                Button(role: .destructive) {
                    model.clearSavedSketches()
                } label: {
                    Label("Clear Saved Sketches", systemImage: "trash")
                }
                .disabled(!model.canClearSavedSketches)
            }
        }
        
        /// The content of the editing menu.
        private var editMenuContent: some View {
            VStack {
                Button {
                    model.geometryEditor.undo()
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .disabled(!model.canUndo)
                
                Button {
                    model.geometryEditor.redo()
                } label: {
                    Label("Redo", systemImage: "arrow.uturn.forward")
                }
                .disabled(!model.canRedo)
                
                Button {
                    model.geometryEditor.deleteSelectedElement()
                } label: {
                    Label("Delete Selected Element", systemImage: "xmark.square.fill")
                }
                .disabled(deleteButtonIsDisabled)
                
                Toggle("Uniform Scale", isOn: $model.shouldUniformScale)
                
                Button(role: .destructive) {
                    model.geometryEditor.clearGeometry()
                } label: {
                    Label("Clear Current Sketch", systemImage: "trash")
                }
                .disabled(!model.canClearCurrentSketch)
                
                Divider()
                
                Button {
                    model.save()
                } label: {
                    Label("Save Sketch", systemImage: "square.and.arrow.down")
                }
                .disabled(!model.canSave)
                
                Button {
                    model.stop()
                } label: {
                    Label("Cancel Sketch", systemImage: "xmark")
                }
            }
        }
    }
}
