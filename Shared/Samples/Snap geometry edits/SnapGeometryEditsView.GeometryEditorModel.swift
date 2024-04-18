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
import Combine

extension SnapGeometryEditsView {
    /// An object that acts as a view model for the geometry editor menu.
    @MainActor
    class GeometryEditorModel: ObservableObject {
        /// The geometry editor.
        let geometryEditor = GeometryEditor()
        
        /// The graphics overlay used to save geometries to.
        let geometryOverlay = GraphicsOverlay(renderingMode: .dynamic)
        
        /// A Boolean value indicating if the geometry editor can perform an undo.
        @Published private(set) var canUndo = false
        
        /// A Boolean value indicating if the geometry editor can perform a redo.
        @Published private(set) var canRedo = false
        
        /// A Boolean value indicating if the geometry can be saved to a graphics overlay.
        @Published private(set) var canSave = false
        
        /// A Boolean value indicating if the geometry can be cleared from the geometry editor.
        @Published private(set) var canClearCurrentSketch = false
        
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
        /// - Precondition: `canSave`
        func save() {
            precondition(canSave)
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
}
