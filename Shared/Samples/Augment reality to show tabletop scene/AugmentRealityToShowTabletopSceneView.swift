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

struct AugmentRealityToShowTabletopSceneView: View {
    /// A scene with a world elevation source.
    @State private var scene: ArcGIS.Scene = {
        let scene = Scene()
        scene.baseSurface.addElevationSource(
            ArcGISTiledElevationSource(url: .worldElevationService)
        )
        return scene
    }()
    
    /// A Boolean value that indicates whether to show an error alert.
    @State private var isShowingErrorAlert = false
    
    /// The error shown in the error alert.
    @State private var error: Error? {
        didSet { isShowingErrorAlert = error != nil }
    }
    
    var body: some View {
        SceneView(scene: scene)
            .alert(isPresented: $isShowingErrorAlert, presentingError: error)
    }
}

private extension URL {
    /// A URL to world elevation service from Terrain3D ArcGIS REST service.
    static var worldElevationService: Self {
        .init(string: "https://elevation3d.arcgis.com/arcgis/rest/services/WorldElevation3D/Terrain3D/ImageServer")!
    }
}
