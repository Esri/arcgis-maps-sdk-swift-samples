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

struct AddIntegratedMeshLayerView: View {
    /// A scene with an imagery basemap style and an integrated mesh layer.
    @State private var scene: ArcGIS.Scene = {
        let scene = Scene(basemapStyle: .arcGISImagery)
        // Creates the elevation source.
        let elevationSource = ArcGISTiledElevationSource(
            url: URL(string: "https://elevation3d.arcgis.com/arcgis/rest/services/WorldElevation3D/Terrain3D/ImageServer")!
        )
        // Creates the surface and adds it to the scene.
        let surface = Surface()
        surface.addElevationSource(elevationSource)
        scene.baseSurface = surface
        
        // Creates the integrated mesh layer that depicts Girona, Spain from
        // a scene service and adds it to the scene.
        let integratedMeshLayer = IntegratedMeshLayer(
            url: URL(string: "https://tiles.arcgis.com/tiles/z2tnIkrLQ2BRzr6P/arcgis/rest/services/Girona_Spain/SceneServer")!
        )
        scene.addOperationalLayer(integratedMeshLayer)
        return scene
    }()
    
    /// A Boolean value indicating when the draw status becomes completed
    /// for the first time.
    @State private var initialDrawCompleted = false

    /// The camera for zooming the scene view to the location.
    @State private var camera: Camera? = Camera(
        latitude: 41.9906,
        longitude: 2.8259,
        altitude: 200,
        heading: 190,
        pitch: 65,
        roll: 0
    )
    
    var body: some View {
        SceneView(scene: scene, camera: $camera)
            .onDrawStatusChanged { drawStatus in
                // Updates the the Boolean when the scene view's draw status
                // becomes completed for the first time.
                withAnimation {
                    if !initialDrawCompleted && drawStatus == .completed {
                        initialDrawCompleted = true
                    }
                }
            }
            .overlay(alignment: .center) {
                if !initialDrawCompleted {
                    ProgressView("Loading...")
                        .padding()
                        .background(.ultraThickMaterial)
                        .clipShape(.rect(cornerRadius: 10))
                        .shadow(radius: 50)
                }
            }
    }
}

#Preview {
    AddIntegratedMeshLayerView()
}
