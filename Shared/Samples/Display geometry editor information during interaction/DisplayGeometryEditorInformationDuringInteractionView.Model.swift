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

extension DisplayGeometryEditorInformationDuringInteractionView {
    /// A model that manages the map, graphics, and geometry editing session.
    @MainActor
    @Observable
    final class Model {
        /// A map centered on Redlands, California.
        let map: Map = {
            let map = Map(basemapStyle: .arcGISStreets)
            map.initialViewpoint = Viewpoint(
                center: Point(
                    x: -13_045_202.018086127,
                    y: 4_035_612.571361517,
                    spatialReference: .webMercator
                ),
                scale: 17_000
            )
            return map
        }()

        /// The graphics overlay containing the geometries to edit.
        let graphicsOverlay = GraphicsOverlay(renderingMode: .dynamic)
        /// The geometry editor used to edit identified graphics.
        let geometryEditor: GeometryEditor = {
            let configuration = InteractionConfiguration()
            configuration.allowsVertexCreation = false
            configuration.allowsMidVertexSelection = false
            configuration.allowsDeletingSelectedElement = false
            configuration.allowsVertexSelection = false
            configuration.allowsPartCreation = false

            let vertexTool = VertexTool()
            vertexTool.configuration = configuration

            let geometryEditor = GeometryEditor()
            geometryEditor.tool = vertexTool
            return geometryEditor
        }()

        /// A Boolean value indicating whether an editing session is active.
        private(set) var isEditing = false
        /// A Boolean value indicating whether the last edit can be undone.
        private(set) var canUndo = false
        /// A Boolean value indicating whether the last undone edit can be redone.
        private(set) var canRedo = false
        /// The information displayed for the current editing interaction.
        private(set) var interactionInformation: String?

        /// The graphic currently being edited.
        private var editingGraphic: Graphic?

        /// The text displayed over the map.
        var informationText: String {
            if let interactionInformation {
                interactionInformation
            } else if isEditing {
                "Move, rotate, or scale the selected geometry."
            } else {
                "Tap a graphic to start the geometry editor."
            }
        }

        init() {
            let lineSymbol = SimpleLineSymbol(color: .red, width: 2)
            let polygonSymbol = SimpleFillSymbol(color: .clear, outline: lineSymbol)
            let markerSymbol = SimpleMarkerSymbol(style: .circle, color: .blue, size: 8)

            graphicsOverlay.addGraphics([
                Graphic(geometry: Self.redlandsMultipoint, symbol: markerSymbol),
                Graphic(geometry: Self.redlandsPolygon, symbol: polygonSymbol),
                Graphic(geometry: Self.redlandsPolyline, symbol: lineSymbol)
            ])
        }

        /// Starts editing the given graphic and hides its original geometry.
        func startEditing(_ graphic: Graphic) {
            guard let geometry = graphic.geometry else { return }
            editingGraphic = graphic
            graphic.isVisible = false
            geometryEditor.start(withInitial: geometry)
            geometryEditor.selectGeometry()
            isEditing = true
        }

        /// Saves the edited geometry to the graphic and stops editing.
        func saveEdits() {
            guard let editingGraphic else { return }
            editingGraphic.geometry = geometryEditor.stop()
            finishEditing()
        }

        /// Discards the edited geometry and stops editing.
        func discardEdits() {
            guard editingGraphic != nil else { return }
            geometryEditor.stop()
            finishEditing()
        }

        /// Observes whether geometry edits can be undone.
        func observeCanUndo() async {
            for await canUndo in geometryEditor.$canUndo {
                self.canUndo = canUndo
            }
        }

        /// Observes whether geometry edits can be redone.
        func observeCanRedo() async {
            for await canRedo in geometryEditor.$canRedo {
                self.canRedo = canRedo
            }
        }

        /// Observes interaction previews and updates the information text.
        func observeInteractionPreviews() async {
            for await preview in geometryEditor.interactionPreviews {
                interactionInformation = preview.flatMap(information(for:))
            }
        }

        /// Creates display information for an interaction preview.
        private func information(for preview: GeometryEditorInteractionPreview) -> String? {
            switch preview.interactionType {
            case .move:
                let center = preview.geometry.extent.center
                return String(format: "Center (X, Y): (%.2f, %.2f)", center.x, center.y)
            case .scale:
                guard let originalExtent = geometryEditor.geometry?.extent,
                      originalExtent.width != 0,
                      originalExtent.height != 0 else { return nil }
                let previewExtent = preview.geometry.extent
                return String(
                    format: "Scale Factor (X, Y): (%.2f, %.2f)",
                    previewExtent.width / originalExtent.width,
                    previewExtent.height / originalExtent.height
                )
            case .rotate:
                guard let originalGeometry = geometryEditor.geometry,
                      let originalPoint = firstPoint(in: originalGeometry),
                      let previewPoint = firstPoint(in: preview.geometry) else { return nil }
                let center = originalGeometry.extent.center
                let cross = (originalPoint.x - center.x) * (previewPoint.y - center.y)
                    - (originalPoint.y - center.y) * (previewPoint.x - center.x)
                let dot = (originalPoint.x - center.x) * (previewPoint.x - center.x)
                    + (originalPoint.y - center.y) * (previewPoint.y - center.y)
                let angle = atan2(cross, dot) * 180 / .pi
                let clockwiseAngle = ((-angle).truncatingRemainder(dividingBy: 360) + 360)
                    .truncatingRemainder(dividingBy: 360)
                return String(format: "Rotation Angle: %.2f°", clockwiseAngle)
            case .create:
                return nil
            @unknown default:
                return nil
            }
        }

        /// Returns the first point in a supported geometry.
        private func firstPoint(in geometry: Geometry) -> Point? {
            switch geometry {
            case let polygon as ArcGIS.Polygon:
                polygon.parts.first?.points.first
            case let polyline as Polyline:
                polyline.parts.first?.points.first
            case let multipoint as Multipoint:
                multipoint.points.first
            default:
                nil
            }
        }

        /// Restores the edited graphic and clears the editing state.
        private func finishEditing() {
            editingGraphic?.isVisible = true
            editingGraphic = nil
            interactionInformation = nil
            isEditing = false
        }

        /// A polygon in Redlands, California.
        private static let redlandsPolygon: ArcGIS.Polygon = try! .fromJSON(
            Data(
                """
                {"rings":[[[-13046991.222211758,4034618.5047884779],[-13046991.222211758,4035962.0723415823],[-13045677.652220398,4035962.0723415823],[-13045677.652220398,4034618.5047884779],[-13046991.222211758,4034618.5047884779]]],"spatialReference":{"wkid":3857}}
                """.utf8
            )
        )

        /// A polyline in Redlands, California.
        private static let redlandsPolyline: Polyline = try! .fromJSON(
            Data(
                """
                {"paths":[[[-13044533.805088846,4034221.5100018946],[-13043597.938505623,4034197.1337576872],[-13043597.938505623,4035135.572073034],[-13044522.634505576,4035170.5449295067]]],"spatialReference":{"wkid":3857}}
                """.utf8
            )
        )

        /// A multipoint in Redlands, California.
        private static let redlandsMultipoint: Multipoint = try! .fromJSON(
            Data(
                """
                {"points":[[-13045283.292102993,4035739.1925106063],[-13045314.922186911,4036533.8852012255],[-13044798.24723932,4036138.7808295386],[-13044354.514637273,4035719.3623426706],[-13044281.57229173,4036473.0999132735]],"spatialReference":{"wkid":3857}}
                """.utf8
            )
        )
    }
}
