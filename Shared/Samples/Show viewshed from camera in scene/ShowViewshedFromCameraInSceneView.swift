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
        SceneView(scene: model.scene, camera: $model.lastCamera)
            .onAppear {
                model.height = 20.0
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
        var lastCamera: Camera?
        
        let analysisOverlay: AnalysisOverlay = {
            let overlay = AnalysisOverlay()
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
            let newViewshed = LocationViewshed(camera: elevatedCamera, minDistance: 1.0, maxDistance: 1000.0)
            analysisOverlay.addAnalysis(newViewshed)
            self.viewshed = newViewshed
        }
        
        private func updateViewshedFromLastCamera() {
            guard let camera = lastCamera else { return }
            updateViewshed(from: camera)
        }
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
