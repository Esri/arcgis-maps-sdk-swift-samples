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

struct AddPointSceneLayerView: View {
    /// A scene with scene layer of world airport locations.
    @State private var scene: ArcGIS.Scene = {
        let scene = Scene(basemapStyle: .arcGISImagery)
        
        // Creates the scene layer using a URL and adds it to the scene.
        let sceneLayer = ArcGISSceneLayer(url: .airportsPointSceneLayer)
        scene.addOperationalLayer(sceneLayer)
        
        // Adds an elevation source to display elevation on the scene's surface.
        let elevationSource = ArcGISTiledElevationSource(url: .worldElevationService)
        scene.baseSurface.addElevationSource(elevationSource)
        
        return scene
    }()
    
    var body: some View {
        // Displays the scene in a scene view.
        SceneView(scene: scene)
    }
}

private extension URL {
    /// A web URL to a scene layer with points at world airport locations.
    static var airportsPointSceneLayer: URL {
        URL(string: "https://tiles.arcgis.com/tiles/V6ZHFr6zdgNZuVG0/arcgis/rest/services/Airports_PointSceneLayer/SceneServer/layers/0")!
    }
    
    /// A web URL to the Terrain3D image server on ArcGIS REST.
    static var worldElevationService: URL {
        URL(string: "https://elevation3d.arcgis.com/arcagis/rest/services/WorldElevation3D/Terrain3D/ImageServer")!
    }
}

#Preview {
    AddPointSceneLayerView()
}
