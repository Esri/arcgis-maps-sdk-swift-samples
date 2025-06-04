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

struct SetAtmosphereEffectInSceneView: View {
    /// A scene with an imagery basemap.
    @State private var scene: ArcGIS.Scene = {
        // Creates a scene and sets an initial viewpoint.
        let scene = Scene(basemapStyle: .arcGISImagery)
        let camera = Camera(
            latitude: 64.416919,
            longitude: -14.483728,
            altitude: 0,
            heading: 318,
            pitch: 105,
            roll: 0
        )
        scene.initialViewpoint = Viewpoint(boundingGeometry: camera.location, camera: camera)
        
        // Creates a surface and adds an elevation source.
        let surface = Surface()
        surface.addElevationSource(ArcGISTiledElevationSource(url: .worldElevationService))
        
        // Sets the surface to the scene's base surface.
        scene.baseSurface = surface
        
        return scene
    }()
    
    /// The scene view's atmosphere effect.
    @State private var atmosphereEffect: SceneView.AtmosphereEffect = .horizonOnly
    
    var body: some View {
        SceneView(scene: scene)
            .atmosphereEffect(atmosphereEffect)
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Picker("Atmosphere Effect", selection: $atmosphereEffect) {
                        ForEach(SceneView.AtmosphereEffect.allCases, id: \.self) { atmosphereEffect in
                            Text(atmosphereEffect.label)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
    }
}

private extension SceneView.AtmosphereEffect {
    /// A human-readable label for each atmosphere effect.
    var label: String {
        switch self {
        case .horizonOnly: return "Horizon Only"
        case .realistic: return "Realistic"
        case .off: return "Off"
        @unknown default: return "Unknown"
        }
    }
}

private extension URL {
    /// The URL of the Terrain 3D ArcGIS REST Service.
    static var worldElevationService: URL {
        URL(string: "https://elevation3d.arcgis.com/arcgis/rest/services/WorldElevation3D/Terrain3D/ImageServer")!
    }
}

#Preview {
    SetAtmosphereEffectInSceneView()
}
