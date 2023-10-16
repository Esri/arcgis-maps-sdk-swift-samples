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
    /// An empty scene.
    @State private var scene = ArcGIS.Scene()
    
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
                    // Load a mobile scene package from a URL.
                    let package = MobileScenePackage(fileURL: .philadelphia)
                    try await package.load()
                    
                    // Set up the scene with first scene in the package.
                    if let scene = package.scenes.first {
                        // Create an elevation source from a URL and add to the scene's base surface.
                        let elevationSource = ArcGISTiledElevationSource(url: .worldElevationService)
                        scene.baseSurface.addElevationSource(elevationSource)
                        
                        // Configure the scene's surface opacity and navigation constraint.
                        scene.baseSurface.opacity = 0
                        scene.baseSurface.navigationConstraint = .unconstrained
                        
                        self.scene = scene
                    }
                } catch {
                    self.error = error
                }
            }
            .alert(isPresented: $isShowingErrorAlert, presentingError: error)
    }
}

private extension URL {
    /// A URL to mobile scene package of Philadelphia, Pennsylvania on ArcGIS Online.
    static var philadelphia: Self {
        Bundle.main.url(forResource: "philadelphia", withExtension: "mspk")!
    }
    
    /// A URL to world elevation service from Terrain3D ArcGIS REST service.
    static var worldElevationService: Self {
        .init(string: "https://elevation3d.arcgis.com/arcgis/rest/services/WorldElevation3D/Terrain3D/ImageServer")!
    }
}
