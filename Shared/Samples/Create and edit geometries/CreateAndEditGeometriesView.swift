// Copyright 2023 Esri
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
struct CreateAndEditGeometriesView: View {
    /// The map to display in the view.
    @State private var map = Map(basemapStyle: .arcGISTopographic)
    
    /// The model that is required by the menu.
    @StateObject var model = GeometryEditorMenuModel(
        geometryEditor: GeometryEditor(),
        graphicsOverlay: GraphicsOverlay(renderingMode: .dynamic)
    )
    
    var body: some View {
        VStack {
            MapView(map: map, graphicsOverlays: [model.graphicsOverlay])
                .geometryEditor(model.geometryEditor)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                GeometryEditorMenu(model: model)
            }
        }
    }
}

/// A view that provides a menu for geometry editor functionality.
struct GeometryEditorMenu: View {
    /// The model for the menu.
    @ObservedObject var model: GeometryEditorMenuModel
    
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
}

extension GeometryEditorMenu {
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

extension GeometryEditorMenu {
    /// A Boolean value indicating whether the selection can be deleted.
    ///
    /// In some instances deleting the selection may be invalid. One example would be the mid vertex
    /// of a line.
    var deleteButtonIsDisabled: Bool {
        guard let selection = model.selection else { return true }
        return !selection.canBeDeleted
    }
}

/// An object that acts as a view model for the geometry editor menu.
@MainActor
class GeometryEditorMenuModel: ObservableObject {
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
            canSave = geometry?.sketchIsValid ?? false
        }
    }
    
    /// A Boolean value indicating if the geometry editor has started.
    @Published var isStarted = false
    
    /// A Boolean value indicating if the scale mode is uniform.
    @Published var shouldUniformScale = false {
        didSet {
            configureGeometryEditorTool(geometryEditor.tool, scaleMode: scaleMode)
        }
    }
    
    /// The scale mode to be set on the geometry editor.
    private var scaleMode: GeometryEditorScaleMode {
        shouldUniformScale ? .uniform : .stretch
    }
    
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
    /// - Precondition: `canSave`
    func save() {
        precondition(canSave)
        let geometry = geometryEditor.geometry!
        let graphic = Graphic(geometry: geometry, symbol: symbol(for: geometry))
        graphicsOverlay.addGraphic(graphic)
        stop()
        canClearSavedSketches = true
    }
    
    /// Clears all the saved sketches on the graphics overlay.
    func clearSavedSketches() {
        graphicsOverlay.removeAllGraphics()
        canClearSavedSketches = false
    }
    
    /// Stops editing with the geometry editor.
    func stop() {
        geometryEditor.stop()
        isStarted = false
    }
    
    /// Returns the symbology for graphics saved to the graphics overlay.
    /// - Parameter geometry: The geometry of the graphic to be saved.
    /// - Returns: Either a marker or fill symbol depending on the type of provided geometry.
    private func symbol(for geometry: Geometry) -> Symbol {
        switch geometry {
        case is Point, is Multipoint:
            return SimpleMarkerSymbol(style: .circle, color: .blue, size: 20)
        case is Polyline:
            return SimpleLineSymbol(color: .blue, width: 2)
        case is ArcGIS.Polygon:
            return SimpleFillSymbol(
                color: .gray.withAlphaComponent(0.5),
                outline: SimpleLineSymbol(color: .blue, width: 2)
            )
        default:
            fatalError("Unexpected geometry type")
        }
    }
    
    /// Configures the scale mode for the geometry editor tool.
    /// - Parameters:
    ///   - tool: The geometry editor tool.
    ///   - scaleMode: Preserve the original aspect ratio or scale freely.
    func configureGeometryEditorTool(_ tool: GeometryEditorTool, scaleMode: GeometryEditorScaleMode) {
        switch tool {
        case let tool as FreehandTool:
            tool.configuration.scaleMode = scaleMode
        case let tool as ShapeTool:
            tool.configuration.scaleMode = scaleMode
        case let tool as VertexTool:
            tool.configuration.scaleMode = scaleMode
        default:
            fatalError("Unexpected tool type")
        }
    }
    
    /// Starts editing with the specified tool and geometry type.
    /// - Parameters:
    ///   - tool: The tool to draw with.
    ///   - geometryType: The type of geometry to draw.
    func startEditing(with tool: GeometryEditorTool, geometryType: Geometry.Type) {
        configureGeometryEditorTool(tool, scaleMode: scaleMode)
        geometryEditor.tool = tool
        geometryEditor.start(withType: geometryType)
        isStarted = true
    }
}

#Preview {
    NavigationView {
        CreateAndEditGeometriesView()
    }
}
