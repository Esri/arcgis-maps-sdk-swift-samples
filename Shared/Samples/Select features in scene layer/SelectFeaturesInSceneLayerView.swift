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
    
    // The point on the screen where the user tapped.
    //
    @State private var tapPoint: CGPoint?
    
    // The feature layer that is added on top of the scene
    //
    @State private var sceneLayer = {
        ArcGISSceneLayer(url: .brestBuildingService)
    }()
    
    /// A scene with topographic basemap and a 3D buildings layer.
    @State private var scene: ArcGIS.Scene = {
        // Creates a scene and sets an initial viewpoint.
        let scene = Scene(basemapStyle: .arcGISTopographic)
        let point = Point(x: -4.49779, y: 48.38282, z: 40, spatialReference: .wgs84)
        // set an initial camera location
        let camera = Camera(location: point, heading: 41.65, pitch: 71.2, roll: 0)
        // set initial viewpoint to camera position at point
        scene.initialViewpoint = Viewpoint(boundingGeometry: point, camera: camera)
        // Creates a surface and adds an elevation source.
        let surface = Surface()
        surface.addElevationSource(ArcGISTiledElevationSource(url: .worldElevationService))
        // Sets the surface to the scene's base surface.
        scene.baseSurface = surface
        return scene
    }()
    
    // Add feature layer to scene in initialization
    
    init() {
        scene.addOperationalLayer(sceneLayer)
    }
    
    var body: some View {
        // Wrap the SceneView in SceneViewReader and expose its SceneViewProxy.
        SceneViewReader { sceneViewProxy in
            SceneView(scene: scene)
                // Capture location of tap on screen
                .onSingleTapGesture { screenPoint, _ in
                    tapPoint = screenPoint
                }
                .task(id: tapPoint) {
                    // clear previous selections
                    sceneLayer.clearSelection()
                    do {
                        // ensure there is a tap point captures
                        guard let locationPoint = tapPoint else { return }
                        // get a list of possible of the elements that were tapped
                        let result = try await sceneViewProxy.identify(on: sceneLayer, screenPoint: locationPoint, tolerance: 10)
                        // grab the first selected element in the array
                        guard let feature = result.geoElements.first as? ArcGISFeature else { return }
                        // highlight the selected feature
                        sceneLayer.selectFeature(feature)
                    } catch {
                       return
                    }
                }
        }
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
