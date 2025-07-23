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

struct ShowViewshedFromCameraInSceneView: View {
    /// The view model for the sample.
    @State private var model = Model()
    
    /// A Boolean value indicating whether the settings sheet is presented.
    @State private var isPresented = false
    
    var body: some View {
        ZStack {
            SceneView(
                scene: model.scene,
                camera: $model.lastCamera,
                graphicsOverlays: [model.graphicsOverlay],
                analysisOverlays: [model.analysisOverlay]
            )
            .onAppear {
                model.setInitialViewshed()
                model.updateViewshedFromLastCamera()
            }
            .onTapGesture {
                model.height += 10
            }
            Button("Set new camera viewpoint") {
                model.updateViewshedFromLastCamera()
            }
        }
        .navigationTitle("Show Viewshed from Camera")
    }
}

private extension ShowViewshedFromCameraInSceneView {
    @MainActor
    @Observable
    final class Model {
        var height: Double = 20.0 {
            didSet {
                updateViewshedFromLastCamera()
            }
        }
        
        private var viewshed: LocationViewshed?
        
        // Camera 150m above ground looking down at 45 degrees pitch
        var lastCamera: Camera? = Camera(
            location: Point(
                x: 2.8214,
                y: 41.9794,
                z: 500,
                spatialReference: .wgs84
            ),
            heading: 0,
            pitch: 45,
            roll: 0
        )
        
        let analysisOverlay: AnalysisOverlay = {
            let overlay = AnalysisOverlay()
            return overlay
        }()
        
        let graphicsOverlay: GraphicsOverlay = {
            let overlay = GraphicsOverlay()
            return overlay
        }()
        
        let scene: ArcGIS.Scene = {
            let scene = Scene(basemapStyle: .arcGISImagery)
            let elevation = ArcGISTiledElevationSource(url: .elevationService)
            scene.baseSurface.addElevationSource(elevation)
            let meshLayer = IntegratedMeshLayer(url: .gironaMeshService)
            scene.addOperationalLayer(meshLayer)
            
            return scene
        }()
        
        init() {
            let viewpoint = Viewpoint(
                boundingGeometry: Point(
                    x: 2.8214,
                    y: 41.9794,
                    z: 500,
                    spatialReference: .wgs84
                ),
                camera: lastCamera ?? .initialCamera
            )
            scene.initialViewpoint = viewpoint
            setInitialViewshed()
        }
        
        func updateViewshed(from camera: Camera) {
            lastCamera = camera
            // Remove previous viewshed cleanly
            if let viewshed = viewshed {
                analysisOverlay.removeAnalysis(viewshed)
            }
            
            let location = camera.location
            let elevatedPoint = Point(
                x: location.x,
                y: location.y,
                z: height,
                spatialReference: location.spatialReference
            )
            let elevatedCamera = Camera(
                location: elevatedPoint,
                heading: camera.heading,
                pitch: camera.pitch,
                roll: camera.roll
            )
            let newViewshed = LocationViewshed(
                camera: elevatedCamera,
                minDistance: 1.0,
                maxDistance: 1000.0
            )
            
            // Set colors: visible area green, obstructed area red
            Viewshed.visibleColor = UIColor.green.withAlphaComponent(0.5)
            Viewshed.obstructedColor = UIColor.red.withAlphaComponent(0.5)
            analysisOverlay.addAnalysis(newViewshed)
            self.viewshed = newViewshed
            
            // Clear previous graphics
            graphicsOverlay.removeAllGraphics()
            
            // Create a simple marker symbol
            let markerSymbol = SimpleMarkerSymbol(style: .circle, color: .blue, size: 12)
            
            // Create a graphic at the elevated point
            let graphic = Graphic(geometry: elevatedPoint, symbol: markerSymbol)
            
            // Add the graphic to the graphics overlay
            graphicsOverlay.addGraphic(graphic)
        }
        
        func updateViewshedFromLastCamera() {
            guard let camera = lastCamera else { return }
            updateViewshed(from: camera)
        }
        
        func setInitialViewshed() {
            guard let camera = lastCamera else { return }
            let newViewshed = LocationViewshed(
                camera: camera,
                minDistance: 1.0,
                maxDistance: 1000.0
            )
            let location = camera.location
            let elevatedPoint = Point(
                x: location.x,
                y: location.y,
                z: 500,
                spatialReference: location.spatialReference
            )
            // Set colors: visible area green, obstructed area red
            Viewshed.visibleColor = UIColor.green.withAlphaComponent(0.5)
            Viewshed.obstructedColor = UIColor.red.withAlphaComponent(0.5)
            analysisOverlay.addAnalysis(newViewshed)
            self.viewshed = newViewshed
            
            // Clear previous graphics
            graphicsOverlay.removeAllGraphics()
            
            // Create a simple marker symbol
            let markerSymbol = SimpleMarkerSymbol(style: .circle, color: .blue, size: 12)
            
            // Create a graphic at the elevated point
            let graphic = Graphic(geometry: elevatedPoint, symbol: markerSymbol)
            
            // Add the graphic to the graphics overlay
            graphicsOverlay.addGraphic(graphic)
        }
    }
}

private extension Camera {
    static var initialCamera: Camera {
        Camera(
            location: Point(
                x: 2.8214,
                y: 41.9794,
                z: 300,
                spatialReference: .wgs84
            ),
            heading: 0,
            pitch: 45,
            roll: 0
        )
    }
}

private extension Point {
    static var initialPoint: Point {
        Point(
            latitude: 41.9794,
            longitude: 2.8214
        )
    }
}
private extension URL {
    static var elevation: URL {
        URL(string: "https://elevation3d.arcgis.com/arcgis/rest/services/WorldElevation3D/Terrain3D/ImageServer")!
    }
    
    static var gironaMeshService: URL {
        URL(string: "https://tiles.arcgis.com/tiles/P3ePLMYs2RVChkJx/arcgis/rest/services/Girona_3D/SceneServer")!
    }
}
