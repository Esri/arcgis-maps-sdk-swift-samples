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

struct SelectFeaturesInSceneLayerView: View {
    /// The error shown in the error alert.
    @State private var error: Error?
    
    /// The point on the screen where the user tapped.
    @State private var tapPoint: CGPoint?
    
    /// The scene layer that is added on top of the scene.
    @State private var sceneLayer = ArcGISSceneLayer(url: .brestBuildingService)
    
    /// A scene with topographic basemap and a 3D buildings layer.
    @State private var scene: ArcGIS.Scene = {
        // Creates a scene and sets an initial viewpoint.
        let scene = Scene(basemapStyle: .arcGISTopographic)
        // Set an initial camera location.
        let camera = Camera(
            latitude: 48.38282,
            longitude: -4.49779,
            altitude: 40,
            heading: 41.65,
            pitch: 71.2,
            roll: 0
        )
        // Set initial viewpoint to camera position at point.
        scene.initialViewpoint = Viewpoint(boundingGeometry: camera.location, camera: camera)
        // Creates a surface and adds an elevation source.
        let surface = Surface()
        surface.addElevationSource(ArcGISTiledElevationSource(url: .worldElevationService))
        // Sets the surface to the scene's base surface.
        scene.baseSurface = surface
        return scene
    }()
    
    /// Add feature layer to scene in initialization.
    init() {
        scene.addOperationalLayer(sceneLayer)
    }
    
    var body: some View {
        SceneViewReader { sceneViewProxy in
            SceneView(scene: scene)
            // Captures location of tap on screen.
                .onSingleTapGesture { screenPoint, _ in
                    tapPoint = screenPoint
                }
                .task(id: tapPoint) {
                    // Clear the previous selections.
                    sceneLayer.clearSelection()
                    do {
                        guard let locationPoint = tapPoint else { return }
                        // Gets the identify results from the tap point.
                        let result = try await sceneViewProxy.identify(on: sceneLayer, screenPoint: locationPoint, tolerance: 10)
                        // Gets the first feature from the identify results.
                        guard let feature = result.geoElements.first as? ArcGISFeature else { return }
                        // Selects the feature in the scene layer.
                        sceneLayer.selectFeature(feature)
                    } catch {
                        self.error = error
                    }
                }
        }.errorAlert(presentingError: $error)
    }
}

private extension URL {
    /// The URL of a Brest, France buildings scene service.
    static var brestBuildingService: URL {
        URL(string: "https://tiles.arcgis.com/tiles/P3ePLMYs2RVChkJx/arcgis/rest/services/Buildings_Brest/SceneServer/layers/0")!
    }
    
    /// The URL of the Terrain 3D ArcGIS REST Service.
    static var worldElevationService: URL {
        URL(string: "https://elevation3d.arcgis.com/arcgis/rest/services/WorldElevation3D/Terrain3D/ImageServer")!
    }
}

#Preview {
    SelectFeaturesInSceneLayerView()
}
