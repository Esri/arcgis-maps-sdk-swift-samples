// Copyright 2023 Esri
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
import ArcGISToolkit
import SwiftUI

struct AugmentRealityToFlyOverSceneView: View {
    /// A scene with an imagery basemap, a world elevation source, and a mesh layer of Girona, Spain.
    @State private var scene: ArcGIS.Scene = {
        let scene = Scene(basemapStyle: .arcGISImagery)
        
        // Create a mesh layer from a URL and add it to the scene.
        let meshLayer = IntegratedMeshLayer(url: .gironaSpain)
        scene.addOperationalLayer(meshLayer)
        
        // Create an elevation source from a URL and add to the scene's base surface.
        let elevationSource = ArcGISTiledElevationSource(url: .worldElevationService)
        scene.baseSurface.addElevationSource(elevationSource)
        
        return scene
    }()
    
    var body: some View {
        // Create a flyover scene view with an initial location, translation factor,
        // initial heading, and scene view.
        FlyoverSceneView(
            initialLocation: Point(x: 2.82407, y: 41.99101, z: 230, spatialReference: .wgs84),
            translationFactor: 1_000,
            initialHeading: 160
        ) { _ in
            SceneView(scene: scene)
                .spaceEffect(.stars)
                .atmosphereEffect(.realistic)
        }
    }
}

private extension URL {
    /// A URL to an integrated mesh layer of Girona, Spain.
    static var gironaSpain: Self {
        .init(string: "https://tiles.arcgis.com/tiles/z2tnIkrLQ2BRzr6P/arcgis/rest/services/Girona_Spain/SceneServer")!
    }
    
    /// A URL to world elevation service from Terrain3D ArcGIS REST service.
    static var worldElevationService: Self {
        .init(string: "https://elevation3d.arcgis.com/arcgis/rest/services/WorldElevation3D/Terrain3D/ImageServer")!
    }
}

#Preview {
    AugmentRealityToFlyOverSceneView()
}
