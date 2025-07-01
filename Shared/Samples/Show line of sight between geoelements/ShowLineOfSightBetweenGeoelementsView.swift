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

struct ShowLineOfSightBetweenGeoelementsView: View {
    @State private var scene = Scene(basemapStyle: .arcGISImagery)
    
    @State private var point = Point(
        x: -73.984988,
        y: 40.748131,
        spatialReference: .wgs84
    )
    
    @State private var lineOfSight: GeoElementLineOfSight?
    
    @State private var analysisOverlay = AnalysisOverlay()
    
    @State private var elevation = Surface()
    
    @State private var buildingLayer = ArcGISSceneLayer(url: .buildingsService)
    
    @State private var graphicsOverlay = GraphicsOverlay()
    
    @State private var taxiGraphic: Graphic?
    
    @State var observerGraphic: Graphic?
    
    init() {
        scene.baseSurface.addElevationSource(ArcGISTiledElevationSource(url: .elevationService))
        scene.addOperationalLayer(buildingLayer)
        graphicsOverlay.sceneProperties = .init(surfacePlacement: .relative)
            }
    
    var body: some View {
        SceneView(
            scene: scene,
            graphicsOverlays: [graphicsOverlay],
            analysisOverlays: [analysisOverlay]
        )
        .onAppear {
            scene.initialViewpoint = Viewpoint(center: point, scale: 1600)
        }
        .task {
            var symbol = SimpleMarkerSceneSymbol(style: .sphere, color: .red, height: 5, width: 5, depth: 5, anchorPosition: .bottom)
            var graphic = Graphic(geometry: point, symbol: symbol)
            observerGraphic = graphic
            graphicsOverlay.addGraphic(graphic)

            let sceneSymbol = ModelSceneSymbol(url: .taxi)
            do {
                try await sceneSymbol.load()
                sceneSymbol.anchorPosition = .bottom
                taxiGraphic = Graphic(
                    geometry: Point(
                        x: -73.984513,
                        y: 40.748469,
                        spatialReference: .wgs84
                    ),
                    symbol: sceneSymbol
                )
                graphicsOverlay.addGraphic(taxiGraphic!)
                if let observer = observerGraphic, let taxi = taxiGraphic {
                    lineOfSight = GeoElementLineOfSight(observer: observer, target: taxi)
                    lineOfSight?.targetOffsetZ = 2
                    if let lineOfSight = lineOfSight {
                        analysisOverlay.addAnalysis(lineOfSight)
                    }
                }
            } catch {
                print(error)
            }
        }
    }
}

extension URL {
    // URL of the elevation service - provides elevation component of the scene
    static var elevationService: URL {
        URL(string: "https://elevation3d.arcgis.com/arcgis/rest/services/WorldElevation3D/Terrain3D/ImageServer")!
    }
    
    // URL of the building service - provides builiding models
    static var buildingsService: URL {
        URL(string: "https://tiles.arcgis.com/tiles/z2tnIkrLQ2BRzr6P/arcgis/rest/services/Buildings_NewYork_v18/SceneServer/layers/0")!
    }
    
    /// A URL to the local Bristol 3D model files.
    static var taxi: URL {
        Bundle.main.url(forResource: "dolmus", withExtension: "3ds", subdirectory: "Dolmus3ds")!
    }
}
#Preview {
    ShowLineOfSightBetweenGeoelementsView()
}
