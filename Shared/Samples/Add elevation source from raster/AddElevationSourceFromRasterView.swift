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

struct AddElevationSourceFromRasterView: View {
    /// A scene with elevation for Monterey, California.
    @State private var scene: ArcGIS.Scene = {
        let scene = Scene(basemapStyle: .arcGISImagery)
        
        // Creates the raster elevation source using a URL.
        let rasterElevationSource = RasterElevationSource(fileURLs: [.montereyElevation])
        
        // Creates a surface to add the elevation source to the scene.
        let surface = Surface()
        surface.addElevationSource(rasterElevationSource)
        scene.baseSurface = surface
        
        // Sets the scene's initial camera to showcase the elevation.
        let camera = Camera(
            latitude: 36.525,
            longitude: -121.8,
            altitude: 300,
            heading: 180,
            pitch: 80,
            roll: 0
        )
        let viewpoint = Viewpoint(latitude: .nan, longitude: .nan, scale: .nan, camera: camera)
        scene.initialViewpoint = viewpoint
        
        return scene
    }()
    
    var body: some View {
        // Displays the scene in a scene view.
        SceneView(scene: scene)
    }
}

private extension URL {
    /// The URL to the local DTED2 Raster file with elevation for Monterey, California.
    static var montereyElevation: URL {
        Bundle.main.url(forResource: "MontereyElevation", withExtension: "dt2")!
    }
}
