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
        // A viewpoint centered at the island of Inis Meáin (Aran Islands) in Ireland.
        map.initialViewpoint = Viewpoint(
            center: Point(latitude: 53.08230, longitude: -9.5920),
            scale: 5_000
        )
        return map
    }()
    
    /// The view model for this sample.
    @StateObject private var model = GeometryEditorModel()
    
    /// The screen point to perform an identify operation.
    @State private var identifyScreenPoint: CGPoint?
    
    var body: some View {
        VStack {
            MapViewReader { proxy in
                MapView(map: map, graphicsOverlays: [model.geometryOverlay])
                    .geometryEditor(model.geometryEditor)
                    .onSingleTapGesture { screenPoint, _ in
                        identifyScreenPoint = screenPoint
                    }
                    .task(id: identifyScreenPoint) {
                        guard let identifyScreenPoint,
                              let identifyResult = try? await proxy.identify(
                                on: model.geometryOverlay,
                                screenPoint: identifyScreenPoint,
                                tolerance: 5
                              ),
                              let graphic = identifyResult.graphics.first,
                              !model.isStarted else { return }
                        model.startEditing(with: graphic)
                    }
            }
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
                model.deleteAllGeometries()
            } label: {
                Label("Delete All Geometries", systemImage: "trash")
            }
            .disabled(!model.canClearGraphics)
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
    
    /// A Boolean value indicating if the initial graphics and saved sketches can be cleared.
    @Published private(set) var canClearGraphics = false
    
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
    
    /// The selected graphic to edit.
    private var selectedGraphic: Graphic?
    
    init() {
        let boundaryGraphic = Graphic(geometry: .boundary(), symbol: .polygon)
        
        let road1Graphic = Graphic(geometry: .road1(), symbol: .polyline)
        
        let road2Graphic = Graphic(geometry: .road2(), symbol: .polyline)
        
        let outbuildingsGraphic = Graphic(geometry: .outbuildings(), symbol: .multipoint)
        
        let houseGraphic = Graphic(geometry: .house(), symbol: .point)
        
        geometryOverlay.addGraphics([
            boundaryGraphic,
            road1Graphic,
            road2Graphic,
            outbuildingsGraphic,
            houseGraphic
        ])
        
        canClearGraphics = true
    }
    
    /// Saves the current geometry to the graphics overlay and stops editing.
    /// - Precondition: Geometry's sketch must be valid.
    func save() {
        precondition(geometryEditor.geometry?.sketchIsValid ?? false)
        
        if selectedGraphic != nil {
            // Update geometry for edited graphic.
            updateGraphic()
        } else {
            // Add new graphic.
            addGraphic()
        }
    }
    
    /// Updates the selected graphic with the current geometry.
    private func updateGraphic() {
        guard let selectedGraphic else { return }
        selectedGraphic.geometry = geometryEditor.stop()
        isStarted = false
        selectedGraphic.isVisible = true
        self.selectedGraphic = nil
    }
    
    /// Adds a new graphic for the current geometry to the graphics overlay.
    private func addGraphic() {
        let geometry = geometryEditor.geometry!
        let graphic = Graphic(geometry: geometry, symbol: symbol(for: geometry))
        geometryOverlay.addGraphic(graphic)
        stop()
        canClearGraphics = true
    }
    
    /// Removes the initial graphics and saved sketches on the graphics overlay.
    func deleteAllGeometries() {
        geometryOverlay.removeAllGraphics()
        canClearGraphics = false
    }
    
    /// Stops editing with the geometry editor.
    func stop() {
        geometryEditor.stop()
        isStarted = false
        selectedGraphic?.isVisible = true
    }
    
    /// Returns the symbology for graphics saved to the graphics overlay.
    /// - Parameter geometry: The geometry of the graphic to be saved.
    /// - Returns: Either a marker or fill symbol depending on the type of provided geometry.
    private func symbol(for geometry: Geometry) -> Symbol {
        switch geometry {
        case is Point:
            return .point
        case is Multipoint:
            return .multipoint
        case is Polyline:
            return .polyline
        case is ArcGIS.Polygon:
            return .polygon
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
    
    /// Starts editing a given graphic with the geometry editor.
    /// - Parameter graphic: The graphic to edit.
    func startEditing(with graphic: Graphic) {
        selectedGraphic = graphic
        graphic.isVisible = false
        let geometry = graphic.geometry!
        geometryEditor.start(withInitial: geometry)
        isStarted = true
    }
}

private extension Geometry {
    // swiftlint:disable force_try
    static func house() -> Point {
        let jsonStr = """
                {"x":-1067898.59,
                 "y":6998366.62,
                 "spatialReference":{"latestWkid":3857,"wkid":102100}}
            """
        return try! Point.fromJSON(jsonStr)
    }
    
    static func road1() -> Polyline {
        let jsonStr = """
                {"paths":[[[-1068095.40,6998123.52],[-1068086.16,6998134.60],
                          [-1068083.20,6998160.44],[-1068104.27,6998205.37],
                          [-1068070.63,6998255.22],[-1068014.44,6998291.54],
                          [-1067952.33,6998351.85],[-1067927.93,6998386.93],
                          [-1067907.97,6998396.78],[-1067889.86,6998406.63],
                          [-1067848.08,6998495.26],[-1067832.92,6998521.11]]],
                        "spatialReference":{"latestWkid":3857,"wkid":102100}}
            """
        return try! Polyline.fromJSON(jsonStr)
    }
    
    static func road2() -> Polyline {
        let jsonStr = """
                {"paths":[[[-1067999.28,6998061.97],[-1067994.48,6998086.59],
                        [-1067964.53,6998125.37],[-1067952.70,6998215.84],
                        [-1067923.13,6998347.54],[-1067903.90,6998391.86],
                        [-1067895.40,6998422.02],[-1067891.70,6998460.18],
                        [-1067889.49,6998483.56],[-1067880.98,6998527.26]]],
                    "spatialReference":{"latestWkid":3857,"wkid":102100}}
            """
        return try! Polyline.fromJSON(jsonStr)
    }
    
    static func outbuildings() -> Multipoint {
        let jsonStr = """
                {"points":[[-1067984.26,6998346.28],[-1067966.80,6998244.84],
                          [-1067921.88,6998284.65],[-1067934.36,6998340.74],
                          [-1067917.93,6998373.97],[-1067828.30,6998355.28],
                          [-1067832.25,6998339.70],[-1067823.10,6998336.93],
                          [-1067873.22,6998386.78],[-1067896.72,6998244.49]],
                        "spatialReference":{"latestWkid":3857,"wkid":102100}}
            """
        return try! Multipoint.fromJSON(jsonStr)
    }
    
    static func boundary() -> ArcGIS.Polygon {
        let jsonStr = """
                {"rings":[[[-1067943.67,6998403.86],[-1067938.17,6998427.60],
                           [-1067898.77,6998415.86],[-1067888.26,6998398.80],
                           [-1067800.85,6998372.93],[-1067799.61,6998342.81],
                           [-1067809.38,6998330.00],[-1067817.07,6998307.85],
                           [-1067838.07,6998285.34],[-1067849.10,6998250.38],
                           [-1067874.02,6998256.00],[-1067879.87,6998235.95],
                           [-1067913.41,6998245.03],[-1067934.84,6998291.34],
                           [-1067948.41,6998251.90],[-1067961.18,6998186.68],
                           [-1068008.59,6998199.49],[-1068052.89,6998225.45],
                           [-1068039.37,6998261.11],[-1068064.12,6998265.26],
                           [-1068043.32,6998299.88],[-1068036.25,6998327.93],
                           [-1068004.43,6998409.28],[-1067943.67,6998403.86]]],
                        "spatialReference":{"latestWkid":3857,"wkid":102100}}
            """
        return try! Polygon.fromJSON(jsonStr)
    }
    // swiftlint:enable force_try
}

private extension Symbol {
    static var point: SimpleMarkerSymbol {
        SimpleMarkerSymbol(
            style: .square,
            color: .red,
            size: 10
        )
    }
    
    static var multipoint: SimpleMarkerSymbol {
        SimpleMarkerSymbol(
            style: .circle,
            color: .yellow,
            size: 5
        )
    }
    
    static var polyline: SimpleLineSymbol {
        SimpleLineSymbol(
            color: .blue,
            width: 2
        )
    }
    
    static var polygon: SimpleFillSymbol {
        SimpleFillSymbol(
            style: .solid,
            color: .red.withAlphaComponent(0.3),
            outline: SimpleLineSymbol(
                style: .dash,
                color: .black,
                width: 1
            )
        )
    }
}

#Preview {
    NavigationStack {
        CreateAndEditGeometriesView()
    }
}
