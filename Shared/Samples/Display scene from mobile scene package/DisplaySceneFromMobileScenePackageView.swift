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

struct DisplaySceneFromMobileScenePackageView: View {
    /// The scene used to create the scene view.
    @State private var scene = ArcGIS.Scene()
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    var body: some View {
        // Create a scene view with the scene.
        SceneView(scene: scene)
            .task {
                do {
                    // Create a mobile scene package using a URL to a .mspk file.
                    let mobileScenePackage = MobileScenePackage(fileURL: .philadelphia)
                    
                    // Load the package.
                    try await mobileScenePackage.load()
                    
                    // Get the first scene from the package.
                    guard let scene = mobileScenePackage.scenes.first else { return }
                    
                    // Use the scene to update the scene view.
                    self.scene = scene
                } catch {
                    self.error = error
                }
            }
            .errorAlert(presentingError: $error)
    }
}

private extension URL {
    /// A URL to the local mobile scene package of Philadelphia, PA, USA.
    static var philadelphia: URL {
        Bundle.main.url(forResource: "philadelphia", withExtension: "mspk")!
    }
}
