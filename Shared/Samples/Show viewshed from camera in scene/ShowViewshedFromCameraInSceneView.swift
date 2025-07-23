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
    //    @State private var isPresented = false
    //
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
            }
        }
        .navigationTitle("Show Viewshed from Camera")
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button("Viewshed from here") {
                    model.updateViewshedFromLastCamera()
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .padding(.horizontal)
            }
        }
    }
}

private extension ShowViewshedFromCameraInSceneView {
    @MainActor
    @Observable
    final class Model {
        private var viewshed: LocationViewshed?
        
        // Camera 150m above ground looking down at 45 degrees pitch
        var lastCamera: Camera? = .initialCamera
        
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
                center: lastCamera?.location ?? .initPoint,
                scale: 50000,
                camera: lastCamera
            )
            scene.initialViewpoint = viewpoint
        }
        
        func updateViewshed(from camera: Camera) {
            // Remove old viewshed
            if let viewshed = viewshed {
                analysisOverlay.removeAnalysis(viewshed)
            }
            
            let elevatedPoint = Point(
                x: camera.location.x,
                y: camera.location.y,
                z: 300,
                spatialReference: camera.location.spatialReference
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
            
            Viewshed.visibleColor = UIColor.green.withAlphaComponent(0.5)
            Viewshed.obstructedColor = UIColor.red.withAlphaComponent(0.5)
            
            analysisOverlay.addAnalysis(newViewshed)
            self.viewshed = newViewshed
            
            graphicsOverlay.removeAllGraphics()
            let markerSymbol = SimpleMarkerSymbol(style: .circle, color: .blue, size: 12)
            let graphic = Graphic(geometry: elevatedPoint, symbol: markerSymbol)
            graphicsOverlay.addGraphic(graphic)
            lastCamera = elevatedCamera
        }
        
        func updateViewshedFromLastCamera() {
            guard let camera = lastCamera else { return }
            updateViewshed(from: camera)
        }
        
        func setInitialViewshed() {
            guard let camera = lastCamera else { return }
            
            let initialViewshed = LocationViewshed(
                camera: camera,
                minDistance: 1.0,
                maxDistance: 1000.0
            )
            
            Viewshed.visibleColor = UIColor.green.withAlphaComponent(0.5)
            Viewshed.obstructedColor = UIColor.red.withAlphaComponent(0.5)
            
            analysisOverlay.addAnalysis(initialViewshed)
            self.viewshed = initialViewshed
            
            graphicsOverlay.removeAllGraphics()
            let markerSymbol = SimpleMarkerSymbol(style: .circle, color: .blue, size: 12)
            let graphic = Graphic(geometry: camera.location, symbol: markerSymbol)
            graphicsOverlay.addGraphic(graphic)
        }
    }
}

private extension Camera {
    static var initialCamera: Camera {
        Camera(
            location: Point(
                x: 2.8214,
                y: 41.985,
                z: 124.987,
                spatialReference: .wgs84
            ),
            heading: 332.131,
            pitch: 82.4732,
            roll: 0
        )
    }
}

extension Point {
    static var initPoint: Point {
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
