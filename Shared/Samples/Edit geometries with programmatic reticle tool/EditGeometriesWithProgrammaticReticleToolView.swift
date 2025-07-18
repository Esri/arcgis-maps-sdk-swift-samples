// Copyright 2025 Esri
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

struct EditGeometriesWithProgrammaticReticleToolView: View {
    /// A map with an imagery basemap.
    @State private var map: Map = {
        let map = Map(basemapStyle: .arcGISImagery)
        map.initialViewpoint = .ireland
        return map
    }()
    
    /// The view model for this sample.
    @State private var model = GeometryEditorModel()
    
    /// The screen point to perform an identify operation.
    @State private var identifyScreenPoint: CGPoint?
    
    var body: some View {
        VStack {
            MapViewReader { mapViewProxy in
                MapView(map: map, graphicsOverlays: [model.geometryOverlay])
                    .geometryEditor(model.geometryEditor)
                    .onSingleTapGesture { screenPoint, _ in
                        identifyScreenPoint = screenPoint
                    }
                    .task(id: identifyScreenPoint) {
                        guard let identifyScreenPoint else { return }
                        Task {
                            // If the geometry editor is started, identify the geometry editor result at the tapped position.
                            if model.isStarted {
                                // Identify the geometry editor result at the tapped position.
                                guard let identifyResult = try? await mapViewProxy.identifyGeometryEditor(
                                    screenPoint: identifyScreenPoint,
                                    tolerance: 10
                                ),
                                      let element = identifyResult.elements.first else { return }
                                
                                // If the element is a vertex or mid-vertex, set the viewpoint to its position and select it.
                                if let vertex = element as? GeometryEditorVertex {
                                    await mapViewProxy.setViewpoint(
                                        Viewpoint(
                                            center: element.extent.center,
                                            scale: Viewpoint.ireland.targetScale
                                        ),
                                        duration: 0.3
                                    )
                                    model.geometryEditor.selectVertexAt(
                                        partIndex: vertex.partIndex,
                                        vertexIndex: vertex.vertexIndex
                                    )
                                } else if let midVertex = element as? GeometryEditorMidVertex, model.allowsVertexCreation {
                                    await mapViewProxy.setViewpoint(
                                        Viewpoint(
                                            center: element.extent.center,
                                            scale: Viewpoint.ireland.targetScale
                                        ),
                                        duration: 0.3
                                    )
                                    model.geometryEditor.selectMidVertexAt(
                                        partIndex: midVertex.partIndex,
                                        segmentIndex: midVertex.segmentIndex
                                    )
                                }
                            }
                            
                            // Identify graphics in the graphics overlay using the tapped position.
                            let results = try await mapViewProxy.identifyGraphicsOverlays(
                                screenPoint: identifyScreenPoint,
                                tolerance: 10
                            )
                            
                            guard let selectedGraphic = results.first?.graphics.first,
                                  let geometry = selectedGraphic.geometry else { return }
                            
                            model.startEditing(with: selectedGraphic)
                            
                            // If vertex creation is allowed, set the viewpoint to the center of the selected graphic's geometry.
                            // Otherwise, set the viewpoint to the end point of the first part of the geometry.
                            if model.allowsVertexCreation {
                                await mapViewProxy.setViewpoint(
                                    Viewpoint(
                                        center: geometry.extent.center,
                                        scale: Viewpoint.ireland.targetScale
                                    ),
                                    duration: 0.03
                                )
                            } else {
                                var center: Point?
                                let geometry = model.selectedGraphic?.geometry
                                switch geometry {
                                case is Polygon:
                                    center = (geometry as! ArcGIS.Polygon).parts[0].endPoint
                                case is Polyline:
                                    center = (geometry as! Polyline).parts[0].endPoint
                                case is Multipoint:
                                    center = (geometry as! Multipoint).points.last
                                case is Point:
                                    center = (geometry as! Point)
                                default:
                                    return
                                }
                                guard let center else { return }
                                
                                await mapViewProxy.setViewpoint(
                                    Viewpoint(
                                        center: center,
                                        scale: Viewpoint.ireland.targetScale
                                    ),
                                    duration: 0.03
                                )
                            }
                        }
                    }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                GeometryEditorMenu(model: model)
            }
        }
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button {
                    model.handleReticleState()
                } label: {
                    Text(model.reticleState.label)
                }
                .disabled(!model.geometryEditor.isStarted)
            }
        }
    }
}

/// A view that provides a menu for geometry editor functionality.
private struct GeometryEditorMenu: View {
    /// The model for the menu.
    @State var model: GeometryEditorModel
    
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
                    .task {
                        for await _ in model.geometryEditor.$hoveredElement {
                            // Update reticle state when there is a hovered element update.
                            model.updateReticleState()
                        }
                    }
                    .task {
                        for await _ in model.geometryEditor.$pickedUpElement {
                            // Update reticle state when there is a hovered picked up element update.
                            model.updateReticleState()
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
            Menu("Programmatic Reticle Tool") {
                Button {
                    model.startEditing(withType: Point.self)
                } label: {
                    Label("New Point", systemImage: "smallcircle.filled.circle")
                }
                
                Button {
                    model.startEditing(withType: Polyline.self)
                } label: {
                    Label("New Line", systemImage: "line.diagonal")
                }
                
                Button {
                    model.startEditing(withType: Polygon.self)
                } label: {
                    Label("New Area", systemImage: "skew")
                }
                
                Button {
                    model.startEditing(withType: Multipoint.self)
                } label: {
                    Label("New Multipoint", systemImage: "hand.point.up.braille")
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
            Toggle("Allow vertex creation", isOn: $model.allowsVertexCreation)
                .onChange(of: model.allowsVertexCreation) {
                    model.reticleTool.vertexCreationPreviewIsEnabled = model.allowsVertexCreation
                    model.reticleTool.style.growEffect?.appliesToMidVertices = model.allowsVertexCreation
                }
            
            Button {
                if model.geometryEditor.pickedUpElement != nil {
                    model.geometryEditor.cancelCurrentAction()
                } else {
                    model.geometryEditor.undo()
                }
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
@Observable
private class GeometryEditorModel {
    /// The geometry editor.
    @ObservationIgnored let geometryEditor = GeometryEditor()
    
    /// The programmatic reticle tool.
    @ObservationIgnored let reticleTool = ProgrammaticReticleTool()
    
    /// The graphics overlay used to save geometries to.
    @ObservationIgnored let geometryOverlay = GraphicsOverlay(renderingMode: .dynamic)
    
    /// The selected graphic to edit.
    @ObservationIgnored var selectedGraphic: Graphic?
    
    /// A Boolean value indicating if the initial graphics and saved sketches can be cleared.
    private(set) var canClearGraphics = false
    
    /// A Boolean value indicating if the geometry editor has started.
    private(set) var isStarted = false
    
    /// A Boolean value indicating if vertex creation is allowed.
    var allowsVertexCreation = true
    
    /// The reticle state used to determine the current action of the programmatic reticle tool.
    enum ReticleState {
        case `default`, pickedUp, hoveringVertex, hoveringMidVertex
        
        /// A human-readable label of the property.
        var label: String {
            switch self {
            case .`default`: return "Insert Point"
            case .pickedUp: return "Drop Point"
            case .hoveringVertex: return "Pick up point"
            case .hoveringMidVertex: return "Pick up point"
            }
        }
    }
    
    /// The programmatic reticle state.
    var reticleState: ReticleState = .default
    
    init() {
        let pinkneysGreenGraphic = Graphic(geometry: .pinkneysGreen(), symbol: .polygon)
        
        let beechLodgBoundaryGraphic = Graphic(geometry: .beechLodgeBoundary(), symbol: .polyline)
        
        let treeMarkers = Graphic(geometry: .treeMarkers(), symbol: .multipoint)
        
        geometryOverlay.addGraphics([
            pinkneysGreenGraphic,
            beechLodgBoundaryGraphic,
            treeMarkers
        ])
        
        geometryEditor.tool = reticleTool
        
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
        
        reticleState = .default
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
        reticleState = .default
    }
    
    /// Starts editing with the specified tool and geometry type.
    /// - Parameters:
    ///   - geometryType: The type of geometry to draw.
    func startEditing(withType geometryType: Geometry.Type) {
        geometryEditor.start(withType: geometryType)
        isStarted = true
        reticleState = .default
    }
    
    /// Starts editing a given graphic with the geometry editor.
    /// - Parameter graphic: The graphic to edit.
    func startEditing(with graphic: Graphic) {
        selectedGraphic = graphic
        graphic.isVisible = false
        let geometry = graphic.geometry!
        geometryEditor.start(withInitial: geometry)
        isStarted = true
        updateReticleState()
    }
    
    /// Stops editing with the geometry editor.
    func stop() {
        geometryEditor.stop()
        isStarted = false
        selectedGraphic?.isVisible = true
        selectedGraphic = nil
        reticleState = .default
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
    
    /// Updates the reticle state based on the picked up and hovered elements.
    func updateReticleState() {
        if geometryEditor.pickedUpElement != nil {
            reticleState = .pickedUp
        } else if let hoveredElement = geometryEditor.hoveredElement {
            if allowsVertexCreation {
                // Verticies and mid-vertices can be picked up.
                if hoveredElement is GeometryEditorVertex {
                    reticleState = .hoveringVertex
                } else if hoveredElement is GeometryEditorMidVertex {
                    reticleState = .hoveringMidVertex
                } else {
                    reticleState = .default
                }
            } else {
                // Only verticies can be picked up, mid-vertices cannot be picked up.
                if hoveredElement is GeometryEditorVertex {
                    reticleState = .hoveringVertex
                } else {
                    reticleState = .default
                }
            }
        } else {
            reticleState = .default
        }
    }
    
    /// Handles the reticle state by placing or picking up an element.
    func handleReticleState() {
        switch reticleState {
        case .default, .pickedUp:
            reticleTool.placeElementAtReticle()
        case .hoveringVertex, .hoveringMidVertex:
            reticleTool.selectElementAtReticle()
            reticleTool.pickUpSelectedElement()
        }
    }
}

private extension Geometry {
    // swiftlint:disable force_try
    static func pinkneysGreen() -> ArcGIS.Polygon {
        let json = Data(
            """
                {"rings":[[[-84843.262719916485,6713749.9329888355],[-85833.376589175183,6714679.7122141244],
                           [-85406.822347959576,6715063.9827222107],[-85184.329997390232,6715219.6195847588],
                           [-85092.653857582554,6715119.5391713539],[-85090.446872787768,6714792.7656492386],
                           [-84915.369168906298,6714297.8798246197],[-84854.295522911285,6714080.907587287],
                           [-84843.262719916485,6713749.9329888355]]],
                        "spatialReference":{"wkid":102100,"latestWkid":3857}}
            """.utf8
        )
        return try! Polygon.fromJSON(json)
    }
    
    static func beechLodgeBoundary() -> Polyline {
        let json = Data(
            """
            {"paths":[[[-87090.652708065536,6714158.9244240439],[-87247.362370337316,6714232.880689906],
                       [-87226.314032974493,6714605.4697726099],[-86910.499335316243,6714488.006312645],
                       [-86750.82198052686,6714401.1768307304],[-86749.846825938366,6714305.8450344801]]],
                    "spatialReference":{"wkid":102100,"latestWkid":3857}}
            """.utf8
        )
        return try! Polyline.fromJSON(json)
    }
    
    static func treeMarkers() -> Multipoint {
        let json = Data(
            """
                {"points":[[-86750.751150056443,6713749.4529355941],[-86879.381793060631,6713437.3335486846],
                           [-87596.503104619667,6714381.7342108283],[-87553.257569537804,6714402.0910389507],
                           [-86831.019903597829,6714398.4128562529],[-86854.105933315877,6714396.1957954112],
                           [-86800.624094892439,6713992.3374453448]],
                        "spatialReference":{"wkid":102100,"latestWkid":3857}}"
            """.utf8
        )
        return try! Multipoint.fromJSON(json)
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

private extension Viewpoint {
    /// A viewpoint centered at the island of Inis Meáin (Aran Islands) in Ireland.
    static var ireland: Viewpoint {
        Viewpoint(
            center: Point(latitude: 51.523806, longitude: -0.775395),
            scale: 2e4
        )
    }
}

#Preview {
    EditGeometriesWithProgrammaticReticleToolView()
}
