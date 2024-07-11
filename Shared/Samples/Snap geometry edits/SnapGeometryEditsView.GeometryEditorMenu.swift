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
        
        /// The currently selected element.
        @State private var selectedElement: GeometryEditorElement?
        
        /// The current geometry of the geometry editor.
        @State private var geometry: Geometry?
        
        /// The geometry editor tool used to edit geometries for the most optimal
        /// snapping experience based on the device type.
        private var geometryEditorTool: GeometryEditorTool {
#if targetEnvironment(macCatalyst)
            VertexTool()
#else
            ReticleVertexTool()
#endif
        }
        
        /// A Boolean value indicating if the geometry editor can perform an undo.
        private var canUndo: Bool {
            return model.geometryEditor.canUndo
        }
        
        /// A Boolean value indicating if the geometry editor can perform a redo.
        private var canRedo: Bool {
            return model.geometryEditor.canRedo
        }
        
        /// A Boolean value indicating if the geometry can be saved to a graphics overlay.
        private var canSave: Bool {
            return geometry?.sketchIsValid ?? false
        }
        
        /// A Boolean value indicating if the geometry can be cleared from the geometry editor.
        private var canClearCurrentSketch: Bool {
            return geometry.map { !$0.isEmpty } ?? false
        }
        
        /// A Boolean value indicating whether the selection can be deleted.
        ///
        /// In some instances deleting the selection may be invalid.
        /// One example would be the mid vertex of a line.
        private var deleteButtonIsDisabled: Bool {
            guard let selectedElement else { return true }
            return !selectedElement.canBeDeleted
        }
        
        var body: some View {
            Menu {
                if !model.isStarted {
                    // If the geometry editor is not started, show the main menu.
                    mainMenuContent
                } else {
                    // If the geometry editor is started, show the edit menu.
                    editMenuContent
                        .task {
                            for await geometry in model.geometryEditor.$geometry {
                                // Update geometry when there is an update.
                                self.geometry = geometry
                            }
                        }
                        .task {
                            for await element in model.geometryEditor.$selectedElement {
                                // Update selected element when there is an update.
                                selectedElement = element
                            }
                        }
                }
            } label: {
                Label("Geometry Editor", systemImage: "pencil.tip.crop.circle")
            }
        }
        
        /// The content of the main menu.
        private var mainMenuContent: some View {
            VStack {
                Button("New Point", systemImage: "smallcircle.filled.circle") {
                    model.startEditing(with: geometryEditorTool, geometryType: Point.self)
                }
                
                Button("New Line", systemImage: "line.diagonal") {
                    model.startEditing(with: geometryEditorTool, geometryType: Polyline.self)
                }
                
                Button("New Area", systemImage: "skew") {
                    model.startEditing(with: geometryEditorTool, geometryType: Polygon.self)
                }
                
                Button("New Multipoint", systemImage: "hand.point.up.braille") {
                    model.startEditing(with: geometryEditorTool, geometryType: Multipoint.self)
                }
                
                Button("New Freehand Line", systemImage: "scribble") {
                    model.startEditing(with: FreehandTool(), geometryType: Polyline.self)
                }
                
                Button("New Freehand Area", systemImage: "lasso") {
                    model.startEditing(with: FreehandTool(), geometryType: Polygon.self)
                }
                
                Menu("Shapes") {
                    Button("New Line Arrow", systemImage: "arrowshape.right") {
                        model.startEditing(with: ShapeTool(kind: .arrow), geometryType: Polyline.self)
                    }
                    
                    Button("New Polygon Arrow", systemImage: "arrowshape.right.fill") {
                        model.startEditing(with: ShapeTool(kind: .arrow), geometryType: Polygon.self)
                    }
                    
                    Button("New Line Rectangle", systemImage: "rectangle") {
                        model.startEditing(with: ShapeTool(kind: .rectangle), geometryType: Polyline.self)
                    }
                    
                    Button("New Polygon Rectangle", systemImage: "rectangle.fill") {
                        model.startEditing(with: ShapeTool(kind: .rectangle), geometryType: Polygon.self)
                    }
                    
                    Button("New Line Ellipse", systemImage: "circle") {
                        model.startEditing(with: ShapeTool(kind: .ellipse), geometryType: Polyline.self)
                    }
                    
                    Button("New Polygon Ellipse", systemImage: "circle.fill") {
                        model.startEditing(with: ShapeTool(kind: .ellipse), geometryType: Polygon.self)
                    }
                    
                    Button("New Line Triangle", systemImage: "triangle") {
                        model.startEditing(with: ShapeTool(kind: .triangle), geometryType: Polyline.self)
                    }
                    
                    Button("New Polygon Triangle", systemImage: "triangle.fill") {
                        model.startEditing(with: ShapeTool(kind: .triangle), geometryType: Polygon.self)
                    }
                }
                
                Divider()
                
                Button("Clear Saved Sketches", systemImage: "trash", role: .destructive) {
                    model.clearSavedSketches()
                }
                .disabled(!model.canClearSavedSketches)
            }
        }
        
        /// The content of the editing menu.
        private var editMenuContent: some View {
            VStack {
                Button("Undo", systemImage: "arrow.uturn.backward") {
                    model.geometryEditor.undo()
                }
                .disabled(!canUndo)
                
                Button("Redo", systemImage: "arrow.uturn.forward") {
                    model.geometryEditor.redo()
                }
                .disabled(!canRedo)
                
                Button("Delete Selected Element", systemImage: "xmark.square.fill") {
                    model.geometryEditor.deleteSelectedElement()
                }
                .disabled(deleteButtonIsDisabled)
                
                Toggle("Uniform Scale", isOn: $model.isUniformScale)
                
                Button("Clear Current Sketch", systemImage: "trash", role: .destructive) {
                    model.geometryEditor.clearGeometry()
                }
                .disabled(!canClearCurrentSketch)
                
                Divider()
                
                Button("Save Sketch", systemImage: "square.and.arrow.down") {
                    model.save()
                }
                .disabled(!canSave)
                
                Button("Cancel Sketch", systemImage: "xmark") {
                    model.stop()
                }
            }
        }
    }
}
