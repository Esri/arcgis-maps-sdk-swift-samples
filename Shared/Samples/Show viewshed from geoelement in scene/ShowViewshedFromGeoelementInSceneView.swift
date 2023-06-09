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
    
    var body: some View {
        SceneView(scene: model.scene,
                  cameraController: model.cameraController,
                  graphicsOverlays: [model.graphicsOverlay],
                  analysisOverlays: [model.analysisOverlay]
        )
        .alert(isPresented: $model.isShowingAlert, presentingError: model.error)
    }
}

private extension ShowViewshedFromGeoelementInSceneView {
    /// The view model for the sample.
    class Model: ObservableObject {
        /// A scene with an imagery basemap and centered on mountains in Chile.
        let scene: ArcGIS.Scene = {
            // Creates a scene.
            let scene = Scene(basemapStyle: .arcGISImagery)
            
            // Add elevation source to the base surface of the scene with the service URL.
            let elevationSource = ArcGISTiledElevationSource(url: .brestElevationService)
            scene.baseSurface.addElevationSource(elevationSource)
            
            // Create the building layer and add it to the scene.
            let buildingsLayer = ArcGISSceneLayer(url: .brestBuildingsService)
            // Offset the altitude to avoid clipping with the elevation source.
            buildingsLayer.altitudeOffset = -45
            scene.addOperationalLayer(buildingsLayer)
            
            // Set scene the viewpoint specified by the camera position.
            let point = Point(x: -73.0870, y: -49.3460, z: 5046, spatialReference: .wgs84)
            let camera = Camera(location: point, heading: 11, pitch: 62, roll: 0)
            scene.initialViewpoint = Viewpoint(boundingGeometry: point, camera: camera)
            
            return scene
        }()
        
        /// The graphic for the tank.
        let tankGraphic: Graphic = {
            // let tankSymbol = ModelSceneSymbol(name: "bradle", extension: "3ds", scale: 10.0)
            // tankSymbol.heading = 90.0
            // tankSymbol.anchorPosition = .bottom
            let tankGraphic = Graphic(
                geometry: Point(x: -4.506390, y: 48.385624, spatialReference: .wgs84),
                //vsymbol: tankSymbol,
                attributes: ["HEADING": 0.0]
            )
            return tankGraphic
        }()
        
        /// The analysis overlay
        lazy var analysisOverlay: AnalysisOverlay = {
            // Create a viewshed to attach to the tank.
            let geoElementViewshed = GeoElementViewshed(
                geoElement: tankGraphic,
                horizontalAngle: 90.0,
                verticalAngle: 40.0,
                headingOffset: 0.0,
                pitchOffset: 0.0,
                minDistance: 0.1,
                maxDistance: 250.0
            )
            
            // Offset viewshed observer location to top of tank.
            geoElementViewshed.offsetZ = 3.0
            
            // Create an analysis overlay to add the viewshed to the scene view
            return AnalysisOverlay(analyses: [geoElementViewshed])
        }()
        
        /// The graphics overlay for the tank.
        lazy var graphicsOverlay: GraphicsOverlay = {
            let graphicsOverlay = GraphicsOverlay(graphics: [tankGraphic])
            graphicsOverlay.sceneProperties = LayerSceneProperties(surfacePlacement: .relative)
            
            // Set up heading expression for tank.
            let renderer3D = SimpleRenderer()
            let sceneProperties = RendererSceneProperties(headingExpression: "[heading] + 90", pitchExpression: "[pitch]", rollExpression: "[roll]")
            sceneProperties.headingExpression = "[HEADING]"
            renderer3D.sceneProperties = sceneProperties
            graphicsOverlay.renderer = renderer3D
            
            return graphicsOverlay
        }()
        
        /// A camera controller set to follow the tank
        lazy var cameraController: CameraController = {
            let cameraController = OrbitGeoElementCameraController(
                target: tankGraphic,
                distance: 200.0
            )
            cameraController.cameraPitchOffset = 45.0
            return cameraController
        }()
        
        /// A Boolean value indicating whether to show an alert.
        @Published var isShowingAlert = false
        
        /// The error shown in the alert.
        @Published var error: Error? {
            didSet { isShowingAlert = error != nil }
        }
    }
}

private extension URL {
    /// A scene service URL for buildings in Brest, France.
    static var brestElevationService: URL {
        URL(string: "https://tiles.arcgis.com/tiles/P3ePLMYs2RVChkJx/arcgis/rest/services/Buildings_Brest/SceneServer/layers/0")!
    }
    
    /// A scene service URL for buildings in Brest, France.
    static var brestBuildingsService: URL {
        URL(string: "https://tiles.arcgis.com/tiles/P3ePLMYs2RVChkJx/arcgis/rest/services/Buildings_Brest/SceneServer/layers/0")!
    }
}
