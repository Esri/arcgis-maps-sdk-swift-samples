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
import SwiftUI

struct AugmentRealityToFlyOverSceneView: View {
    /// A scene with an imagery basemap with a world elevation service.
    @State private var scene: ArcGIS.Scene = {
        let scene = Scene(basemapStyle: .arcGISImagery)
        scene.baseSurface.addElevationSource(
            ArcGISTiledElevationSource(url: .worldElevationService)
        )
        return scene
    }()
    
    /// The camera to set the initial camera of the flyover scene.
    private let initialCamera: Camera = {
        let location = Point(x: 2.8262, y: 41.9857, z: 200, spatialReference: .wgs84)
        return Camera(location: location, heading: 190, pitch: 90, roll: 0)
    }()
    
    /// A Boolean value indicating whether to show an error alert.
    @State private var isShowingErrorAlert = false
    
    /// The error shown in the error alert.
    @State private var error: Error? {
        didSet { isShowingErrorAlert = error != nil }
    }
    
    var body: some View {
        SceneView(scene: scene)
            .task {
                do {
                    // Create a mesh layer from a url.
                    let meshLayer = IntegratedMeshLayer(url: .girona)
                    
                    // Load the layer.
                    try await meshLayer.load()
                    
                    // Add mesh layer to the scene.
                    scene.addOperationalLayer(meshLayer)
                } catch {
                    self.error = error
                }
            }
            .alert(isPresented: $isShowingErrorAlert, presentingError: error)
    }
}

private extension URL {
    /// A URL to an integrated mesh layer of Girona, Spain.
    static var girona: Self {
        .init(string: "https://tiles.arcgis.com/tiles/z2tnIkrLQ2BRzr6P/arcgis/rest/services/Girona_Spain/SceneServer")!
    }
    
    /// A URL to world elevation service from Terrain3D ArcGIS REST service.
    static var worldElevationService: Self {
        .init(string: "https://elevation3d.arcgis.com/arcgis/rest/services/WorldElevation3D/Terrain3D/ImageServer")!
    }
}
