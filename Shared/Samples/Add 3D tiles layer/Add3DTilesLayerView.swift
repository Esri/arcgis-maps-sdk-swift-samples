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

struct Add3DTilesLayerView: View {
    /// A scene with dark gray basemap and an OGC 3D tiles layer.
    @State private var scene: ArcGIS.Scene = {
        // Creates a scene and sets an initial viewpoint.
        let scene = Scene(basemapStyle: .arcGISDarkGray)
        let camera = Camera(
            latitude: 48.84553,
            longitude: 9.16275,
            altitude: 350,
            heading: 0,
            pitch: 75,
            roll: 0
        )
        scene.initialViewpoint = Viewpoint(boundingGeometry: camera.location, camera: camera)
        
        // Creates a surface and adds an elevation source.
        let surface = Surface()
        surface.addElevationSource(ArcGISTiledElevationSource(url: .worldElevationService))
        
        // Sets the surface to the scene's base surface.
        scene.baseSurface = surface
        
        // Creates an OGC 3D tiles layer from a 3D tiles service URL.
        let ogc3DTileslayer = OGC3DTilesLayer(url: .stuttgart3DTiles)
        
        // Adds the layer to the scene's operational layers.
        scene.addOperationalLayer(ogc3DTileslayer)
        return scene
    }()
    
    var body: some View {
        SceneView(scene: scene)
    }
}

private extension URL {
    /// The URL of a Stuttgart, Germany city 3D tiles service.
    static var stuttgart3DTiles: URL {
        URL(string: "https://tiles.arcgis.com/tiles/N82JbI5EYtAkuUKU/arcgis/rest/services/Stuttgart/3DTilesServer/tileset.json")!
    }
    
    /// The URL of the Terrain 3D ArcGIS REST Service.
    static var worldElevationService: URL {
        URL(string: "https://elevation3d.arcgis.com/arcgis/rest/services/WorldElevation3D/Terrain3D/ImageServer")!
    }
}

#Preview {
    Add3DTilesLayerView()
}
