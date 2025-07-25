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
    /// A camera for the scene that determines where the viewshed is set from.
    @State private var camera: Camera?
    
    /// The viewshed which is updated by the camera.
    @State private var viewshed: LocationViewshed
    
    /// A 3D Scene setup with imagery basemap, elevation, and mesh layer.
    @State private var scene: ArcGIS.Scene = {
        let scene = Scene(basemapStyle: .arcGISImagery)
        scene.baseSurface.addElevationSource(
            ArcGISTiledElevationSource(
                url: URL(string: "https://elevation3d.arcgis.com/arcgis/rest/services/WorldElevation3D/Terrain3D/ImageServer")!
            )
        )
        scene.addOperationalLayer(
            IntegratedMeshLayer(
                url: URL(string: "https://tiles.arcgis.com/tiles/P3ePLMYs2RVChkJx/arcgis/rest/services/Girona_3D/SceneServer")!
            )
        )
        return scene
    }()
    
    /// An analysis overlay used to display the viewshed analysis visualization.
    /// The viewshed which is updated by the camera.
    @State private var analysisOverlay = AnalysisOverlay()
    
    init() {
        let camera = Camera(
            location: Point(
                x: 2.8214,
                y: 41.985,
                z: 200.0,
                spatialReference: .wgs84
            ),
            heading: 332.131,
            pitch: 82.4732,
            roll: 0
        )
        self.camera = camera
        
        self.viewshed = LocationViewshed(
            camera: camera,
            minDistance: 1.0,
            maxDistance: 1_000.0
        )
        
        // Set visual appearance of the viewshed.
        Viewshed.visibleColor = .green.withAlphaComponent(0.5)
        Viewshed.obstructedColor = .red.withAlphaComponent(0.5)
        
        // Add the new viewshed to the overlay.
        analysisOverlay.addAnalysis(viewshed)
    }
    
    var body: some View {
        SceneView(
            scene: scene,
            camera: $camera,
            analysisOverlays: [analysisOverlay]
        )
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button("Viewshed from here") {
                    guard let camera else { return }
                    
                    // Update viewshed based on current camera location when button is tapped.
                    viewshed.update(from: camera)
                }
            }
        }
    }
}
