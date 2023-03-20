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
    @State private var graphicsOverlay = GraphicsOverlay(renderingMode: .dynamic)
    
    var body: some View {
        VStack {
            MapView(map: map, graphicsOverlays: [graphicsOverlay])
                .geometryEditor(geometryEditor)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                GeometryEditorMenu(geometryEditor: geometryEditor, graphicsOverlay: graphicsOverlay)
            }
        }
    }
}

/// A view that provides a menu for geometry editor functionality.
struct GeometryEditorMenu: View {
    /// The model for the menu.
    @ObservedObject var model: Model
    
    init(geometryEditor: GeometryEditor, graphicsOverlay: GraphicsOverlay) {
        model = Model(geometryEditor: geometryEditor, graphicsOverlay: graphicsOverlay)
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
                    Label("New Line", systemImage: "pencil.line")
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
                    Label("New Freehand Area", systemImage: "lasso")
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
    }
}

extension GeometryEditorMenu {
    /// An object that acts as a view model for the geometry editor menu.
    @MainActor class Model: ObservableObject {
        /// The geometry editor.
        let geometryEditor: GeometryEditor
        
        /// The graphics overlay used to save geometries to.
        let graphicsOverlay: GraphicsOverlay
        
        /// A Boolean value indicating if the geometry editor can perform an undo.
        @Published private(set) var canUndo = false
        
        /// A Boolean value indicating if the geometry editor can perform a redo.
        @Published private(set) var canRedo = false
        
        /// The currently selected element.
        @Published private(set) var selection: GeometryEditorElement?
        
        /// A Boolean value indicating if the geometry can be saved to a graphics overlay.
        @Published private(set) var canSave = false
        
        /// A Boolean value indicating if the geometry can be cleared from the geometry editor.
        @Published private(set) var canClearCurrentSketch = false
        
        /// A Boolean value indicating if the saved sketches can be cleared.
        @Published private(set) var canClearSavedSketches = false
        
        /// The current geometry of the geometry editor.
        @Published private(set) var geometry: Geometry? {
            didSet {
                canUndo = geometryEditor.canUndo
                canRedo = geometryEditor.canRedo
                canClearCurrentSketch = geometry.map { !$0.isEmpty } ?? false
                canSave = true //geometry.map { GeometryBuilder.builder(from: $0).sketchIsValid } ?? false
            }
        }
        
        /// A Boolean value indicating if the geometry editor has started.
        @Published var isStarted = false
        
        /// Creates the geometry menu with a geometry editor.
        /// - Parameter geometryEditor: The geometry editor that the menu should interact with.
        /// - Parameter graphicsOverlay: The graphics overlay that is used to save geometries to.
        init(geometryEditor: GeometryEditor, graphicsOverlay: GraphicsOverlay) {
            self.geometryEditor = geometryEditor
            self.graphicsOverlay = graphicsOverlay
            
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
        
        /// Saves the current geometry to the graphics overlay and stops editing.
        /// Precondition: `canSave`
        func save() {
            let geometry = geometryEditor.geometry!
            let graphic = Graphic(geometry: geometry, symbol: symbol(for: geometry))
            graphicsOverlay.addGraphic(graphic)
            stop()
            canClearSavedSketches = true
        }
        
        func clearSavedSketches() {
            graphicsOverlay.removeAllGraphics()
            canClearSavedSketches = false
        }
        
        /// Stops editing with the geometry editor.
        func stop() {
            geometryEditor.stop()
            isStarted = false
        }
        
        func symbol(for geometry: Geometry) -> Symbol {
            switch geometry {
            case is Point, is Multipoint:
                return SimpleMarkerSymbol(style: .circle, color: .blue, size: 20)
            case is Polyline:
                return SimpleLineSymbol(color: .blue, width: 2)
            case is Polygon:
                return SimpleFillSymbol(
                    color: .gray.withAlphaComponent(0.5),
                    outline: SimpleLineSymbol(color: .blue, width: 2)
                )
            default:
                fatalError("Unexpected geometry type")
            }
        }
    }
}
