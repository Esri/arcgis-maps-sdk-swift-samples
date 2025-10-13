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

struct DisplayLocalSceneView: View {
    /// A local scene with topographic basemap style and a tiled elevation source.
    @State private var scene: ArcGIS.Scene = {
        let scene = Scene(
            basemapStyle: .arcGISTopographic,
            viewingMode: .local
        )
        
        // Add surface.
        
        let surface = Surface()
        let elevationSource = ArcGISTiledElevationSource(
            url: URL(string: "https://elevation3d.arcgis.com/arcgis/rest/services/WorldElevation3D/Terrain3D/ImageServer")!
        )
        surface.addElevationSource(elevationSource)
        scene.baseSurface = surface
        
        // Add layer.
        
        let sceneLayer = ArcGISSceneLayer(
            url: URL(string: "https://www.arcgis.com/home/item.html?id=61da8dc1a7bc4eea901c20ffb3f8b7af")!
        )
        
        scene.addOperationalLayer(sceneLayer)
        
        // Set clipping area.
        
        scene.clippingArea = Envelope(
            xRange: 19_454_578.8235...19_455_518.8814,
            yRange: -5_055_381.4798 ... -5_054_888.4150,
            spatialReference: .webMercator
        )
        scene.clippingIsEnabled = true
        
        // Set intial viewpoint.
        
        let camera = Camera(
            location: Point(
                x: 19_455_578.6821,
                y: -5_056_336.2227,
                z: 1_699.3366,
                spatialReference: .webMercator
            ),
            heading: 338.7410,
            pitch: 40.3763,
            roll: 0
        )
        scene.initialViewpoint = Viewpoint(
            center: Point(x: 19_455_026.8116, y: -5_054_995.7415, spatialReference: .webMercator),
            scale: 8_314.6991,
            camera: camera
        )
        
        return scene
    }()
    
    var body: some View {
        LocalSceneView(scene: scene)
    }
}

#Preview {
    DisplayLocalSceneView()
}
