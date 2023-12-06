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
    /// The scene used to create the scene view.
    @State private var scene = ArcGIS.Scene()
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    /// The location point of the scene that will be anchored on a physical surface.
    private let anchorPoint = Point(
        latitude: 39.95787000283599,
        longitude: -75.16996728256345
    )
    
    /// The translation factor that defines how much the scene view translates as the device moves.
    private let translationFactor = {
        // The width of the scene, which is about 800 m.
        let geographicContentWidth = 800.0
        
        // The physical width of the surface the scene will be placed on in meters.
        let tableContainerWidth = 1.0
        
        return geographicContentWidth / tableContainerWidth
    }()
    
    var body: some View {
        // Create a tabletop scene view using a scene view.
        TableTopSceneView(
            anchorPoint: anchorPoint,
            translationFactor: translationFactor,
            clippingDistance: 400
        ) { _ in
            SceneView(scene: scene)
        }
        .task {
            do {
                // Load a mobile scene package from a URL.
                let package = MobileScenePackage(fileURL: .philadelphia)
                try await package.load()
                
                // Set up the scene using first scene in the package.
                if let scene = package.scenes.first {
                    // Create an elevation source from a URL and add to the scene's base surface.
                    let elevationSource = ArcGISTiledElevationSource(url: .worldElevationService)
                    scene.baseSurface.addElevationSource(elevationSource)
                    
                    // Set the navigation constraint to allow you to look at the scene from below.
                    scene.baseSurface.navigationConstraint = .unconstrained
                    
                    // Update the scene for the scene view.
                    self.scene = scene
                }
            } catch {
                // Present the error loading the mobile scene package.
                self.error = error
            }
        }
        .errorAlert(presentingError: $error)
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
