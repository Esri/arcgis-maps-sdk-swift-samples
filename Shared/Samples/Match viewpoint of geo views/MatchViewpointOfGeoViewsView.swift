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

struct MatchViewpointOfGeoViewsView: View {
    /// A map with an imagery basemap.
    @State private var map = Map(basemapStyle: .arcGISImagery)
    
    /// A scene with an imagery basemap.
    @State private var scene = Scene(basemapStyle: .arcGISImagery)
    
    /// The viewpoint of the map view.
    @State private var mapViewpoint: Viewpoint?
    
    /// The viewpoint of the scene view.
    @State private var sceneViewpoint: Viewpoint?
    
    /// A Boolean value indicating whether the map view is currently being navigated.
    @State private var mapIsNavigating = false
    
    /// A Boolean value indicating whether the map view is currently being navigated.
    @State private var sceneIsNavigating = false
    
    var body: some View {
        VStack(spacing: 0) {
            MapView(map: map, viewpoint: mapViewpoint)
                .onNavigatingChanged { mapIsNavigating = $0 }
                .onViewpointChanged(kind: .centerAndScale) { newViewpoint in
                    // Sets the scene's viewpoint to the map's when the map is navigating,
                    // or when the scene isn't navigating, e.i., when the viewpoint is first set.
                    guard mapIsNavigating || !sceneIsNavigating else { return }
                    sceneViewpoint = newViewpoint
                }
            
            SceneView(scene: scene, viewpoint: sceneViewpoint)
                .onNavigatingChanged { sceneIsNavigating = $0 }
                .onViewpointChanged(kind: .centerAndScale) { newViewpoint in
                    // Sets the map's viewpoint to the scene's when the scene is navigating.
                    guard sceneIsNavigating else { return }
                    mapViewpoint = newViewpoint
                }
        }
    }
}

#Preview {
    MatchViewpointOfGeoViewsView()
}
