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

struct StylePointWithSceneSymbolView: View {
    /// A scene with a topographic basemap and elevation surface.
    @State private var scene: ArcGIS.Scene = {
        // Create a scene with an initial viewpoint.
        let scene = Scene(basemapStyle: .arcGISTopographic)
        let camera = Camera(
            latitude: 48.973,
            longitude: 4.92,
            altitude: 2082,
            heading: 60,
            pitch: 75,
            roll: 0
        )
        scene.initialViewpoint = Viewpoint(latitude: .nan, longitude: .nan, scale: .nan, camera: camera)
        
        // Add an elevation source to the base surface.
        let elevationSource = ArcGISTiledElevationSource(url: .worldElevationService)
        scene.baseSurface.addElevationSource(elevationSource)
        
        return scene
    }()
    
    /// The graphics overlay for the scene symbol graphics.
    @State private var graphicsOverlay: GraphicsOverlay = {
        let graphicsOverlay = GraphicsOverlay()
        graphicsOverlay.sceneProperties.surfacePlacement = .absolute
        return graphicsOverlay
    }()
    
    init() {
        // Add the scene symbol graphics to the graphics overlay.
        graphicsOverlay.addGraphics(makeGraphics())
    }
    
    var body: some View {
        // Add the scene and graphics overlay to a scene view.
        SceneView(scene: scene, graphicsOverlays: [graphicsOverlay])
    }
    
    /// Creates a graphic for each simple marker scene symbol style.
    /// - Returns: A list of graphics.
    private func makeGraphics() -> [Graphic] {
        // Create a simple maker scene symbol for each style.
        let sceneSymbols = SimpleMarkerSceneSymbol.Style.allCases.map { style in
            SimpleMarkerSceneSymbol(
                style: style,
                color: .random(),
                height: 200,
                width: 200,
                depth: 200,
                anchorPosition: .center
            )
        }
        
        // Create a graphic for each scene symbol.
        let startingX = 4.975
        let graphics = sceneSymbols.enumerated().map { offset, symbol in
            let point = Point(
                x: startingX + 0.01 * Double(offset),
                y: 49,
                z: 500,
                spatialReference: .wgs84
            )
            return Graphic(geometry: point, symbol: symbol)
        }
        
        return graphics
    }
}

private extension UIColor {
    /// Creates a random color whose red, green, and blue values are in the
    /// range `0...1` and whose alpha value is `1`.
    /// - Returns: A new `UIColor` object.
    static func random() -> UIColor {
        let range: ClosedRange<CGFloat> = 0...1
        return UIColor(
            red: .random(in: range),
            green: .random(in: range),
            blue: .random(in: range),
            alpha: 1
        )
    }
}

private extension SimpleMarkerSceneSymbol.Style {
    static var allCases: [Self] {
        return [.cone, .cube, .cylinder, .diamond, .sphere, .tetrahedron]
    }
}

private extension URL {
    /// A world elevation service from the Terrain3D ArcGIS REST service.
    static var worldElevationService: URL {
        URL(string: "https://elevation3d.arcgis.com/arcgis/rest/services/WorldElevation3D/Terrain3D/ImageServer")!
    }
}

#Preview {
    StylePointWithSceneSymbolView()
}
