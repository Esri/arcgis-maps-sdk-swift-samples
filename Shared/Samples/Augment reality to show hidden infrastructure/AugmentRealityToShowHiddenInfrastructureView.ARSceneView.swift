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
import ArcGISToolkit
import SwiftUI

extension AugmentRealityToShowHiddenInfrastructureView {
    /// A world scale scene view displaying pipe graphics from a given model.
    struct ARPipesSceneView: View {
        /// The view model for scene view in the sample.
        @ObservedObject var model: SceneModel
        
        /// A Boolean value indicating whether the shadow graphics are visible.
        @State private var shadowsAreVisible = true
        
        /// A Boolean value indicating whether the leader line graphics are visible.
        @State private var leadersAreVisible = true
        
        var body: some View {
            VStack(spacing: 0) {
                WorldScaleSceneView { _ in
                    SceneView(scene: model.scene, graphicsOverlays: [
                        model.pipeGraphicsOverlay,
                        model.shadowGraphicsOverlay,
                        model.leaderGraphicsOverlay
                    ])
                }
                .calibrationButtonAlignment(.bottomLeading)
                .onCalibratingChanged { newCalibrating in
                    model.scene.baseSurface.opacity = newCalibrating ? 0.6 : 0
                }
                
                Divider()
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    settingsMenu
                }
            }
        }
        
        /// The settings menu.
        private var settingsMenu: some View {
            Menu("Settings") {
                Toggle("Shadows", isOn: $shadowsAreVisible)
                    .onChange(of: shadowsAreVisible) { newValue in
                        model.shadowGraphicsOverlay.isVisible = newValue
                    }
                Toggle("Leaders", isOn: $leadersAreVisible)
                    .onChange(of: leadersAreVisible) { newValue in
                        model.leaderGraphicsOverlay.isVisible = newValue
                    }
            }
        }
    }
}

extension AugmentRealityToShowHiddenInfrastructureView {
    // MARK: Scene Model
    
    /// The view model for scene view in the sample.
    class SceneModel: ObservableObject {
        /// A scene with an imagery basemap style and an elevation surface.
        let scene: ArcGIS.Scene = {
            let scene = Scene(basemapStyle: .arcGISImageryStandard)
            
            // Create a surface with an elevation source and set it to the scene's base surface.
            let surface = Surface()
            surface.navigationConstraint = .unconstrained
            surface.opacity = 0
            surface.backgroundGrid.isVisible = false
            
            let elevationSource = ArcGISTiledElevationSource(url: .worldElevationService)
            surface.addElevationSource(elevationSource)
            scene.baseSurface = surface
            
            return scene
        }()
        
        /// The graphics overlay for the pipe graphics.
        let pipeGraphicsOverlay: GraphicsOverlay = {
            let graphicsOverlay = GraphicsOverlay()
            graphicsOverlay.sceneProperties.surfacePlacement = .absolute
            
            let strokeSymbolLayer = SolidStrokeSymbolLayer(
                width: 0.3,
                color: .red,
                lineStyle3D: .tube
            )
            let polylineSymbol = MultilayerPolylineSymbol(symbolLayers: [strokeSymbolLayer])
            graphicsOverlay.renderer = SimpleRenderer(symbol: polylineSymbol)
            
            return graphicsOverlay
        }()
        
        /// The graphics overlay for the shadow graphics of the underground pipes.
        let shadowGraphicsOverlay: GraphicsOverlay = {
            let graphicsOverlay = GraphicsOverlay()
            graphicsOverlay.sceneProperties.surfacePlacement = .drapedFlat
            
            let yellowLineSymbol = SimpleLineSymbol(style: .solid, color: .systemYellow, width: 0.3)
            graphicsOverlay.renderer = SimpleRenderer(symbol: yellowLineSymbol)
            
            return graphicsOverlay
        }()
        
        /// The graphics overlay for the pipe leader line graphics.
        let leaderGraphicsOverlay: GraphicsOverlay = {
            let graphicsOverlay = GraphicsOverlay()
            graphicsOverlay.sceneProperties.surfacePlacement = .absolute
            
            let dashedRedLineSymbol = SimpleLineSymbol(style: .dash, color: .systemRed, width: 0.3)
            graphicsOverlay.renderer = SimpleRenderer(symbol: dashedRedLineSymbol)
            
            return graphicsOverlay
        }()
        
        init() {
            Task {
                try? await scene.load()
            }
        }
        
        /// Adds graphics created from a given polyline and elevation offset to the graphics overlays.
        /// - Parameters:
        ///   - polyline: The polyline representing a pipe.
        ///   - elevationOffset: An elevation to offset the pipe with.
        func addGraphics(for polyline: Polyline, elevationOffset: Double) async {
            guard let firstPoint = polyline.parts.first?.startPoint,
                  let elevation = try? await scene.baseSurface.elevation(at: firstPoint) else { return }
            
            // Add the elevation with the offset to the polyline.
            let elevatedPolyline = GeometryEngine.makeGeometry(
                from: polyline,
                z: elevation + elevationOffset
            )
            
            // Add a pipe graphic using the elevated polyline.
            let pipeGraphic = Graphic(geometry: elevatedPolyline)
            pipeGraphicsOverlay.addGraphic(pipeGraphic)
            
            // Add graphics for the leader lines.
            let leaderLineGraphics = elevatedPolyline.parts.map { part in
                part.points.map { point in
                    let offsetPoint = GeometryEngine.makeGeometry(
                        from: point,
                        z: (point.z ?? 0) - elevationOffset
                    )
                    let leaderLine = Polyline(points: [point, offsetPoint])
                    return Graphic(geometry: leaderLine)
                }
            }
            leaderGraphicsOverlay.addGraphics(Array(leaderLineGraphics.joined()))
            
            // Add a shadow graphic for the pipe if it is below ground.
            if elevationOffset < 0 {
                let shadowGraphic = Graphic(geometry: polyline)
                shadowGraphicsOverlay.addGraphic(shadowGraphic)
            }
        }
    }
}

private extension URL {
    /// The URL of the Terrain 3D ArcGIS REST Service.
    static var worldElevationService: URL {
        URL(string: "https://elevation3d.arcgis.com/arcgis/rest/services/WorldElevation3D/Terrain3D/ImageServer")!
    }
}
