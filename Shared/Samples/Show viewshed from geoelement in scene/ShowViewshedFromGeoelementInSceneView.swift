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

import SwiftUI
import ArcGIS

struct ShowViewshedFromGeoelementInSceneView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// The timer for the moving tank animation.
    @State private var animationTimer: Timer!
    
    var body: some View {
        SceneView(
            scene: model.scene,
            cameraController: model.cameraController,
            graphicsOverlays: [model.graphicsOverlay],
            analysisOverlays: [model.analysisOverlay]
        )
        .onSingleTapGesture { _, mapPoint in
            // Start a timer to animate the tank moving towards the new waypoint.
            model.waypoint = mapPoint
            animationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                model.animate()
                if model.waypoint == nil {
                    animationTimer.invalidate()
                }
            }
        }
        .overlay(alignment: .top) {
            // Instruction text.
            Text("Tap on the map to move the tank and update the viewshed.")
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial, ignoresSafeAreaEdges: .horizontal)
        }
    }
}

private extension ShowViewshedFromGeoelementInSceneView {
    /// The view model for the sample.
    class Model: ObservableObject {
        /// A scene with an imagery basemap.
        let scene: ArcGIS.Scene = {
            let scene = Scene(basemapStyle: .arcGISImagery)
            
            // Add elevation source to the base surface of the scene with the service URL.
            let elevationSource = ArcGISTiledElevationSource(url: .worldElevationService)
            scene.baseSurface.addElevationSource(elevationSource)
            
            // Create the building layer and add it to the scene.
            let buildingsLayer = ArcGISSceneLayer(url: .brestBuildingsService)
            scene.addOperationalLayer(buildingsLayer)
            
            return scene
        }()
        
        /// A camera controller set to follow the tank.
        let cameraController: CameraController
        
        /// The graphics overlay for the tank graphic.
        let graphicsOverlay: GraphicsOverlay = {
            let graphicsOverlay = GraphicsOverlay()
            graphicsOverlay.sceneProperties = LayerSceneProperties(surfacePlacement: .relative)
            
            // Set up the heading expression for the tank.
            let renderer3D = SimpleRenderer()
            let sceneProperties = RendererSceneProperties(
                headingExpression: "[heading] + 90",
                pitchExpression: "[pitch]",
                rollExpression: "[roll]"
            )
            sceneProperties.headingExpression = "[HEADING]"
            renderer3D.sceneProperties = sceneProperties
            graphicsOverlay.renderer = renderer3D
            
            return graphicsOverlay
        }()
        
        /// The analysis overlay for the tank's viewshed.
        let analysisOverlay = AnalysisOverlay()
        
        /// The graphic for the tank.
        let tankGraphic: Graphic = {
            let tankSymbol = ModelSceneSymbol(url: .bradleyTank, scale: 10)
            tankSymbol.heading = 90
            tankSymbol.anchorPosition = .bottom
            let tankGraphic = Graphic(
                geometry: Point(x: -4.506390, y: 48.385624, spatialReference: .wgs84),
                attributes: ["HEADING": 0.0],
                symbol: tankSymbol
            )
            return tankGraphic
        }()
        
        /// The point for the tank to move toward.
        var waypoint: Point?
        
        init() {
            // Create camera controller.
            cameraController = OrbitGeoElementCameraController(
                target: tankGraphic,
                distance: 200
            )
            
            // Add tank graphic to graphics overlay.
            graphicsOverlay.addGraphic(tankGraphic)
            
            // Create a viewshed to attach to the tank.
            let geoElementViewshed = GeoElementViewshed(
                geoElement: tankGraphic,
                horizontalAngle: 90,
                verticalAngle: 40,
                headingOffset: 0,
                pitchOffset: 0,
                minDistance: 0.1,
                maxDistance: 250
            )
            
            // Offset viewshed observer location to top of tank.
            geoElementViewshed.offsetZ = 3
            
            // Add the viewshed to the analysisOverlay to add to the scene.
            analysisOverlay.addAnalysis(geoElementViewshed)
        }
        
        /// Animate the tank moving from its current point to the waypoint.
        func animate() {
            // Get point from the current tank position.
            guard let tankLocation = tankGraphic.geometry as? Point else { return }
            guard let point = waypoint else { return }
            
            // Get the distance from the current tank location to the waypoint.
            guard let distanceResult = GeometryEngine.geodeticDistance(
                from: tankLocation,
                to: point,
                distanceUnit: .meters,
                azimuthUnit: .degrees,
                curveType: .geodesic
            ) else { return }
            
            // Move toward waypoint a short distance.
            let locations = GeometryEngine.geodeticMove(
                [tankLocation],
                distance: 1,
                distanceUnit: .meters,
                azimuth: distanceResult.azimuth1.value,
                azimuthUnit: distanceResult.azimuth1.unit.angularUnit,
                curveType: .geodesic
            )
            tankGraphic.geometry = locations.first
            
            // Set tank graphic heading.
            if let heading = tankGraphic.attributes["HEADING"] as? Double {
                // Divide by 10 to make the animation more smooth.
                tankGraphic.setAttributeValue(
                    heading + ((distanceResult.azimuth1.value - heading) / 10),
                    forKey: "HEADING"
                )
            }
            
            // Reset waypoint to stop animation when within 5 meters of the waypoint.
            if distanceResult.distance.value <= 5 {
                waypoint = nil
            }
        }
    }
}

private extension URL {
    /// The on-demand resource URL for the Bradley tank.
    static var bradleyTank: URL {
        Bundle.main.url(forResource: "bradle", withExtension: "3ds", subdirectory: "bradley_low_3ds")!
    }
    
    /// A world elevation service from Terrain3D ArcGIS REST service.
    static var worldElevationService: URL {
        URL(string: "https://elevation3d.arcgis.com/arcgis/rest/services/WorldElevation3D/Terrain3D/ImageServer")!
    }
    
    /// A scene service URL for buildings in Brest, France.
    static var brestBuildingsService: URL {
        URL(string: "https://tiles.arcgis.com/tiles/P3ePLMYs2RVChkJx/arcgis/rest/services/Buildings_Brest/SceneServer/layers/0")!
    }
}
