// Copyright 2022 Esri
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

struct AddSceneLayerFromServiceView: View {
    /// A scene with an imagery basemap and a 3D buildings layer.
    @State private var scene: ArcGIS.Scene = {
        // Creates a scene layer using a URL to a scene layer service.
        let sceneLayer = ArcGISSceneLayer(url: .portlandBuildingService)
        
        // Creates a scene and adds the scene layer to its operational layers.
        let scene = Scene(basemapStyle: .arcGISImagery)
        scene.addOperationalLayer(sceneLayer)
        
        // Creates an elevation source and adds it to the scene's base surface.
        let elevationSource = ArcGISTiledElevationSource(url: .worldElevationService)
        scene.baseSurface.addElevationSource(elevationSource)
        
        // Sets the scene's initial viewpoint to center the scene view on the scene layer.
        let point = Point(x: -122.66949, y: 45.51869, z: 227, spatialReference: .wgs84)
        let camera = Camera(location: point, heading: 219, pitch: 82, roll: 0)
        let viewpoint = Viewpoint(latitude: .nan, longitude: .nan, scale: .nan, camera: camera)
        scene.initialViewpoint = viewpoint
        
        return scene
    }()
    
    var body: some View {
        // Displays the scene in a scene view.
        SceneView(scene: scene)
    }
}

private extension URL {
    /// The URL of a scene service containing buildings in Portland, OR, USA.
    static var portlandBuildingService: URL {
        URL(string: "https://tiles.arcgis.com/tiles/P3ePLMYs2RVChkJx/arcgis/rest/services/Buildings_Portland/SceneServer")!
    }
    
    /// The URL of the Terrain 3D ArcGIS REST Service.
    static var worldElevationService: URL {
        URL(string: "https://elevation3d.arcgis.com/arcgis/rest/services/WorldElevation3D/Terrain3D/ImageServer")!
    }
}

#Preview {
    AddSceneLayerFromServiceView()
}
