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
    /// A map with an imagery basemap.
    @State private var map: Map = {
        let map = Map(basemapStyle: .arcGISImagery)
        map.initialViewpoint = Viewpoint(
            center: .aranIslands.center,
            scale: 5_000
        )
        return map
    }()
    
    /// The view model for this sample.
    @StateObject private var model = GeometryEditorModel()
    
    var body: some View {
        VStack {
            MapView(map: map, graphicsOverlays: [model.geometryOverlay])
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
private struct GeometryEditorMenu: View {
    /// The model for the menu.
    @ObservedObject var model: GeometryEditorModel
    
    /// The currently selected element.
    @State private var selectedElement: GeometryEditorElement?
    
    /// The current geometry of the geometry editor.
    @State private var geometry: Geometry?
    
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
}

private extension GeometryEditorMenu {
    /// The content of the main menu.
    var mainMenuContent: some View {
        VStack {
            Menu("Reticle Vertex Tool") {
                Button {
                    model.startEditing(with: ReticleVertexTool(), geometryType: Point.self)
                } label: {
                    Label("New Point", systemImage: "smallcircle.filled.circle")
                }
                
                Button {
                    model.startEditing(with: ReticleVertexTool(), geometryType: Polyline.self)
                } label: {
                    Label("New Line", systemImage: "line.diagonal")
                }
                
                Button {
                    model.startEditing(with: ReticleVertexTool(), geometryType: Polygon.self)
                } label: {
                    Label("New Area", systemImage: "skew")
                }
                
                Button {
                    model.startEditing(with: ReticleVertexTool(), geometryType: Multipoint.self)
                } label: {
                    Label("New Multipoint", systemImage: "hand.point.up.braille")
                }
            }
            
            Menu("Vertex Tool") {
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
            }
            
            Menu("Freehand Tool") {
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
    var editMenuContent: some View {
        VStack {
            Button {
                model.geometryEditor.undo()
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
            }
            .disabled(!canUndo)
            
            Button {
                model.geometryEditor.redo()
            } label: {
                Label("Redo", systemImage: "arrow.uturn.forward")
            }
            .disabled(!canRedo)
            
            Button {
                model.geometryEditor.deleteSelectedElement()
            } label: {
                Label("Delete Selected Element", systemImage: "xmark.square.fill")
            }
            .disabled(deleteButtonIsDisabled)
            
            Toggle("Uniform Scale", isOn: $model.isUniformScale)
            
            Button(role: .destructive) {
                model.geometryEditor.clearGeometry()
            } label: {
                Label("Clear Current Sketch", systemImage: "trash")
            }
            .disabled(!canClearCurrentSketch)
            
            Divider()
            
            Button {
                model.save()
            } label: {
                Label("Save Sketch", systemImage: "square.and.arrow.down")
            }
            .disabled(!canSave)
            
            Button {
                model.stop()
            } label: {
                Label("Cancel Sketch", systemImage: "xmark")
            }
        }
    }
}

private extension GeometryEditorMenu {
    /// A Boolean value indicating whether the selection can be deleted.
    ///
    /// In some instances deleting the selection may be invalid. One example would be the mid vertex
    /// of a line.
    var deleteButtonIsDisabled: Bool {
        guard let selectedElement else { return true }
        return !selectedElement.canBeDeleted
    }
    
    /// A Boolean value indicating if the geometry editor can perform an undo.
    var canUndo: Bool {
        return model.geometryEditor.canUndo
    }
    
    /// A Boolean value indicating if the geometry editor can perform a redo.
    var canRedo: Bool {
        return model.geometryEditor.canRedo
    }
    
    /// A Boolean value indicating if the geometry can be saved to a graphics overlay.
    var canSave: Bool {
        return geometry?.sketchIsValid ?? false
    }
    
    /// A Boolean value indicating if the geometry can be cleared from the geometry editor.
    var canClearCurrentSketch: Bool {
        return geometry.map { !$0.isEmpty } ?? false
    }
}

/// An object that acts as a view model for the geometry editor menu.
@MainActor
private class GeometryEditorModel: ObservableObject {
    /// The geometry editor.
    let geometryEditor = GeometryEditor()
    
    /// The graphics overlay used to save geometries to.
    let geometryOverlay = GraphicsOverlay(renderingMode: .dynamic)
    
    /// A Boolean value indicating if the saved sketches can be cleared.
    @Published private(set) var canClearSavedSketches = false
    
    /// A Boolean value indicating if the geometry editor has started.
    @Published private(set) var isStarted = false
    
    /// A Boolean value indicating if the scale mode is uniform.
    @Published var isUniformScale = false {
        didSet {
            configureGeometryEditorTool(geometryEditor.tool, scaleMode: scaleMode)
        }
    }
    
    /// The scale mode to be set on the geometry editor.
    private var scaleMode: GeometryEditorScaleMode {
        isUniformScale ? .uniform : .stretch
    }
    
    /// Saves the current geometry to the graphics overlay and stops editing.
    /// - Precondition: Geometry's sketch must be valid.
    func save() {
        precondition(geometryEditor.geometry?.sketchIsValid ?? false)
        let geometry = geometryEditor.geometry!
        let graphic = Graphic(geometry: geometry, symbol: symbol(for: geometry))
        geometryOverlay.addGraphic(graphic)
        stop()
        canClearSavedSketches = true
    }
    
    /// Clears all the saved sketches on the graphics overlay.
    func clearSavedSketches() {
        geometryOverlay.removeAllGraphics()
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
    private func configureGeometryEditorTool(_ tool: GeometryEditorTool, scaleMode: GeometryEditorScaleMode) {
        switch tool {
        case let tool as FreehandTool:
            tool.configuration.scaleMode = scaleMode
        case let tool as ShapeTool:
            tool.configuration.scaleMode = scaleMode
        case let tool as VertexTool:
            tool.configuration.scaleMode = scaleMode
        case _ as ReticleVertexTool:
            break
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

private extension Geometry {
    /// The area around the island of Inis Meáin (Aran Islands) in Ireland.
    static var aranIslands: Envelope {
        Envelope(center: Point(x: -9.5920, y: 53.08230, spatialReference: .wgs84), width: 1, height: 1, depth: 1)
    }
}

#Preview {
    NavigationStack {
        CreateAndEditGeometriesView()
    }
}
