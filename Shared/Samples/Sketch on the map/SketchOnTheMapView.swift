// Copyright 2022 Esri
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

/// A view that shows how to interact with the geometry editor.
struct SketchOnTheMapView: View {
    @State private var map = Map(basemapStyle: .arcGISTopographic)
    @State private var geometryEditor = GeometryEditor()
    
    var body: some View {
        VStack {
            MapView(map: map)
                .geometryEditor(geometryEditor)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                GeometryEditorMenu(geometryEditor: geometryEditor)
            }
        }
    }
}

/// A view that provides a menu for geometry editor functionality.
struct GeometryEditorMenu: View {
    /// The model for the menu.
    @ObservedObject var model: Model
    
    init(geometryEditor: GeometryEditor) {
        model = Model(geometryEditor: geometryEditor)
    }
    
    var body: some View {
        Menu {
            Content()
        } label: {
            Label("Geometry Editor", systemImage: "pencil.tip.crop.circle")
        }
        .environmentObject(model)
    }
}

extension GeometryEditorMenu {
    /// The content of a geometry editor menu.
    struct Content: View {
        @EnvironmentObject var model: Model
        
        var body: some View {
            if model.isStarted {
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
                .disabled(model.selection == nil)
                
                Button(role: .destructive) {
                    model.geometryEditor.clearGeometry()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .disabled(model.geometry?.isEmpty ?? true)
                
                Divider()
                
                Button {
                    model.geometryEditor.stop()
                    model.isStarted = false
                } label: {
                    Label("Stop", systemImage: "stop.circle")
                }
            } else {
                Button {
                    model.geometryEditor.tool = VertexTool()
                    model.geometryEditor.start(withType: Point.self)
                    model.isStarted = true
                } label: {
                    Label("New Point", systemImage: "pencil")
                }
                
                Button {
                    model.geometryEditor.tool = VertexTool()
                    model.geometryEditor.start(withType: Polyline.self)
                    model.isStarted = true
                } label: {
                    Label("New Line", systemImage: "scribble")
                }
                
                Button {
                    model.geometryEditor.tool = VertexTool()
                    model.geometryEditor.start(withType: Polygon.self)
                    model.isStarted = true
                } label: {
                    Label("New Area", systemImage: "skew")
                }
                
                Button {
                    model.geometryEditor.tool = VertexTool()
                    model.geometryEditor.start(withType: Multipoint.self)
                    model.isStarted = true
                } label: {
                    Label("New Multipoint", systemImage: "hand.point.up.braille")
                }
                
                Button {
                    model.geometryEditor.tool = FreehandTool()
                    model.geometryEditor.start(withType: Polyline.self)
                    model.isStarted = true
                } label: {
                    Label("New Freehand Line", systemImage: "scribble")
                }

                Button {
                    model.geometryEditor.tool = FreehandTool()
                    model.geometryEditor.start(withType: Polygon.self)
                    model.isStarted = true
                } label: {
                    Label("New Freehand Area", systemImage: "scribble")
                }
            }
        }
    }
}

extension GeometryEditorMenu {
    /// An object that acts as a view model for the geometry editor menu.
    @MainActor class Model: ObservableObject {
        /// The geometry editor.
        let geometryEditor: GeometryEditor
        
        /// A Boolean value indicating if the geometry editor can perform an undo.
        @Published private(set) var canUndo = false
        
        /// A Boolean value indicating if the geometry editor can perform a redo.
        @Published private(set) var canRedo = false
        
        /// The currently selected element.
        @Published private(set) var selection: GeometryEditorElement?
        
        /// The current geometry of the geometry editor.
        @Published private(set) var geometry: Geometry? {
            didSet {
                canUndo = geometryEditor.canUndo
                canRedo = geometryEditor.canRedo
            }
        }
        
        /// A Boolean value indicating if the geometry editor has started.
        @Published var isStarted: Bool = false
        
        /// Creates the geometry menu with a geometry editor.
        /// - Parameter geometryEditor: The geometry editor that the menu should interact with.
        init(geometryEditor: GeometryEditor) {
            self.geometryEditor = geometryEditor
            
            Task { [weak self, geometryEditor] in
                for await geometry in geometryEditor.$geometry {
                    self?.geometry = geometry
                }
            }
            Task { [weak self, geometryEditor] in
                for await selection in geometryEditor.$selectedElement {
                    self?.selection = selection
                }
            }
        }
    }
}
