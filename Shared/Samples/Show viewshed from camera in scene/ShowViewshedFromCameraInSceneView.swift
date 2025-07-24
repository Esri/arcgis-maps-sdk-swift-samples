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
import Observation

struct ShowViewshedFromCameraInSceneView: View {
    /// The view model for the sample.
    @State private var model = Model()
    
    var body: some View {
        SceneView(
            scene: model.scene,
            camera: $model.currentCamera,
            analysisOverlays: [model.analysisOverlay]
        )
        .onAppear {
            // Set up the initial viewshed when the view appears.
            model.setInitialViewshed()
        }
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                viewshedButton
            }
        }
    }
    
    private var viewshedButton: some View {
        Button("Viewshed from here") {
            // Update viewshed based on current camera location when button is tapped.
            model.updateViewshedFromCurrentCamera()
        }
        .buttonStyle(.borderedProminent)
        .tint(.purple)
        .padding(.horizontal)
    }
}

private extension ShowViewshedFromCameraInSceneView {
    /// View model to manage the scene, camera, and viewshed analysis.
    @MainActor
    @Observable
    final class Model {
        var currentCamera: Camera? = .initialCamera
        /// An analysis overlay used to display the viewshed analysis visualization.
        let analysisOverlay = AnalysisOverlay()
        /// The viewshed which is updated by the camera.
        @ObservationIgnored private var viewshed: LocationViewshed?
        /// 3D Scene setup with imagery basemap, elevation, and mesh layer.
        let scene: ArcGIS.Scene = {
            let scene = Scene(basemapStyle: .arcGISImagery)
            scene.baseSurface.addElevationSource(
                ArcGISTiledElevationSource(url: .elevation)
            )
            scene.addOperationalLayer(
                IntegratedMeshLayer(url: .gironaMeshService)
            )
            return scene
        }()
        
        /// Applies a viewshed at the initial camera position.
        func setInitialViewshed() {
            guard let camera = currentCamera else { return }
            setupViewshed(using: camera)
        }
        
        /// Updates the viewshed using the current camera position with added elevation.
        func updateViewshedFromCurrentCamera() {
            guard let camera = currentCamera else { return }
            viewshed?.update(from: camera)
        }
        
        /// Applies the viewshed to the scene and sets the UI for analysis.
        private func setupViewshed(using camera: Camera) {
            // Create and configure the new viewshed.
            let newViewshed = LocationViewshed(
                camera: camera,
                minDistance: 1.0,
                maxDistance: 1000.0
            )
            // Set visual appearance of the viewshed.
            Viewshed.visibleColor = UIColor.green.withAlphaComponent(0.5)
            Viewshed.obstructedColor = UIColor.red.withAlphaComponent(0.5)
            // Add the new viewshed to the overlay.
            analysisOverlay.addAnalysis(newViewshed)
            viewshed = newViewshed
        }
    }
}

private extension Camera {
    static var initialCamera: Camera {
        Camera(
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
