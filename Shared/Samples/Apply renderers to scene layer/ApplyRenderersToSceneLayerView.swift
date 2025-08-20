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

struct ApplyRenderersToSceneLayerView: View {
    @State private var scene: ArcGIS.Scene = {
        var scene = Scene(basemapStyle: .arcGISImagery)
        let sceneLayer = ArcGISSceneLayer(url: .world)
        scene.addOperationalLayer(sceneLayer)
        let elevationSource = ArcGISTiledElevationSource(
            url: .elevation
        )
        // Creates the surface and adds it to the scene.
        let surface = Surface()
        surface.addElevationSource(elevationSource)
        scene.baseSurface = surface
        var point = Point(
            x: 2778453.8008,
            y: 8436451.3882,
            z: 387.4524,
            spatialReference: .webMercator
        )
        let camera = Camera(
            location: point,
            heading: 308.9,
            pitch: 50.7,
            roll: 0.0
        )
        scene.initialViewpoint = Viewpoint(
            boundingGeometry: point,
            camera: camera
        )
        return scene
    }()
    
    var body: some View {
        SceneView(scene: scene)
    }
}

extension ApplyRenderersToSceneLayerView { }

private extension URL {
    static var world: URL {
        URL(string: "https://www.arcgis.com/home/item.html?id=fdfa7e3168e74bf5b846fc701180930b")!
    }
    
    static var elevation: URL {
        URL(string: "https://elevation3d.arcgis.com/arcgis/rest/services/WorldElevation3D/Terrain3D/ImageServer")!
    }
}

#Preview {
    ApplyRenderersToSceneLayerView()
}
