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

struct SetFeatureLayerRenderingModeOnSceneView: View {
    @State private var dynamicScene: ArcGIS.Scene = {
        let scene = Scene()
        return scene
    }()
    
    @State private var staticScene: ArcGIS.Scene = {
        let scene = Scene()
        return scene
    }()
    
    @State private var viewpoint: Viewpoint?
    
    @State private var zoomedOutCamera = Camera(
        lookingAt:
            Point(x: -118.37,
                  y: 34.46,
                  spatialReference: .wgs84
                 ),
        distance: 42000,
        heading: 0,
        pitch: 0,
        roll: 0
    )
    
    @State private var zoomedInCamera = Camera(
        lookingAt: Point(x: -118.45,
                         y: 34.395,
                         spatialReference: .wgs84),
        distance: 2500, heading: 90, pitch: 75, roll: 0)
    
    @State private var isZoomedIn = true
    
    var body: some View {
        SceneView(scene: dynamicScene)
    }
}
