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

struct ShowExtrudedGraphicsView: View {
    /// A scene with a topographic basemap style.
    @State private var scene: ArcGIS.Scene = {
        let scene = Scene(basemapStyle: .arcGISTopographic)
        // Creates the elevation source.
        let elevationSource = ArcGISTiledElevationSource(url: .worldElevationService)
        
        // Add the elevation source to the scene base surface.
        scene.baseSurface.addElevationSource(elevationSource)
        
        let camera = Camera(
            location: .initialLocation,
            heading: 10,
            pitch: 70,
            roll: 0
        )
        scene.initialViewpoint = Viewpoint(boundingGeometry: camera.location, camera: camera)
        
        return scene
    }()
    
    /// The scene view graphics overlay.
    @State private var graphicsOverlay: GraphicsOverlay = {
        // Create a graphics overlay.
        let graphicsOverlay = GraphicsOverlay()
        graphicsOverlay.sceneProperties.surfacePlacement = .drapedBillboarded
        
        // Create a renderer and set its extrusion properties.
        let renderer = SimpleRenderer()
        let lineSymbol = SimpleLineSymbol(style: .solid, color: .white, width: 1)
        renderer.symbol = SimpleFillSymbol(style: .solid, color: .red, outline: lineSymbol)
        renderer.sceneProperties.extrusionMode = .baseHeight
        renderer.sceneProperties.extrusionExpression = "[height]"
        graphicsOverlay.renderer = renderer
        
        return graphicsOverlay
    }()
    
    init() {
        addGraphics()
    }
    
    var body: some View {
        SceneView(scene: scene, graphicsOverlays: [graphicsOverlay])
    }
    
    /// Adds extruded polygon graphics the graphics overlays.
    private func addGraphics() {
        let x = Point.initialLocation.x - 0.01
        let y = Point.initialLocation.y + 0.25
        
        let spacing = 0.01
        
        for column in stride(from: 0.0, to: 6.0, by: 1.0) {
            for row in stride(from: 0.0, to: 4.0, by: 1.0) {
                let startingX: Double = x + column * (.squareSize + spacing)
                let startingY: Double = y + row * (.squareSize + spacing)
                let startingPoint = Point(x: startingX, y: startingY)
                let polygon = ShowExtrudedGraphicsView.polygon(for: startingPoint)
                let graphic = extrudedGraphic(for: polygon)
                graphicsOverlay.addGraphic(graphic)
            }
        }
    }
    
    /// An extruded graphic created from a given polygon with a randon height.
    /// - Parameter polygon: The polygon.
    /// - Returns: A graphic.
    private func extrudedGraphic(for polygon: ArcGIS.Polygon) -> Graphic {
        let maxHeight = 10_000
        let height = Int.random(in: 0...maxHeight)
        let graphic = Graphic(geometry: polygon)
        graphic.setAttributeValue(height, forKey: "height")
        return graphic
    }
    
    /// A square polygon created from a given point.
    /// - Parameter point: The point.
    /// - Returns: A polygon.
    private static func polygon(for point: Point) -> ArcGIS.Polygon {
        let polygon = PolygonBuilder()
        polygon.add(Point(x: point.x, y: point.y))
        polygon.add(Point(x: point.x, y: point.y + .squareSize))
        polygon.add(Point(x: point.x + .squareSize, y: point.y + .squareSize))
        polygon.add(Point(x: point.x + .squareSize, y: point.y))
        return polygon.toGeometry()
    }
}

private extension Double {
    /// The square size of the extruded graphics.
    static var squareSize: Double { 0.01 }
}

private extension Point {
    /// The initial location.
    static var initialLocation: Point {
        Point(x: 83, y: 28.4, z: 20_000)
    }
}

private extension URL {
    /// The URL of the Terrain 3D ArcGIS REST Service.
    static var worldElevationService: URL {
        URL(string: "https://elevation3d.arcgis.com/arcgis/rest/services/WorldElevation3D/Terrain3D/ImageServer")!
    }
}

#Preview {
    ShowExtrudedGraphicsView()
}
