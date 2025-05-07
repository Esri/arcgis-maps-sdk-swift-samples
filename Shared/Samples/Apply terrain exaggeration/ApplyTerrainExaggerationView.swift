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

struct ApplyTerrainExaggerationView: View {
    /// A scene with an elevated surface and a topographic basemap.
    @State private var scene: ArcGIS.Scene = {
        // Creates a scene using a basemap style.
        let scene = Scene(basemapStyle: .arcGISTopographic)
        
        // Creates an elevation source and adds it to the scene's surface.
        let elevationSource = ArcGISTiledElevationSource(url: .worldElevationService)
        scene.baseSurface.addElevationSource(elevationSource)
        
        // Sets the scene's initial viewpoint to center the scene view on Levering, WA, USA.
        let point = Point(latitude: 46.75792, longitude: -119.9489)
        let camera = Camera(lookingAt: point, distance: 15000, heading: 40, pitch: 60, roll: 0)
        scene.initialViewpoint = Viewpoint(latitude: .nan, longitude: .nan, scale: .nan, camera: camera)
        
        return scene
    }()
    
    /// The elevation exaggeration of the scene's surface.
    @State private var elevationExaggeration: Float = 1
    
    var body: some View {
        // Displays the scene in a scene view.
        SceneView(scene: scene)
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Stepper(value: $elevationExaggeration, in: 1...10) {
                        Text("\(elevationExaggeration, format: .number.rounded())x")
                    }
                    .onChange(of: elevationExaggeration) {
                        // Sets the surface's elevation exaggeration when the stepper value changes.
                        scene.baseSurface.elevationExaggeration = elevationExaggeration
                    }
                }
            }
    }
}

private extension URL {
    /// A web URL to the Terrain3D image server on ArcGIS REST.
    static var worldElevationService: URL {
        URL(string: "https://elevation3d.arcgis.com/arcgis/rest/services/WorldElevation3D/Terrain3D/ImageServer")!
    }
}

#Preview {
    ApplyTerrainExaggerationView()
}
