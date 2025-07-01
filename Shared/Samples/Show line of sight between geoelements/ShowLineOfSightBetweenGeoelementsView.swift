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

struct ShowLineOfSightBetweenGeoelementsView: View {
    @State private var scene = Scene(basemapStyle: .arcGISImagery)
    
    @State private var point = Point(
        x: -73.984988,
        y: 40.748131,
        spatialReference: .wgs84
    )
    
    @State private var lineOfSight: GeoElementLineOfSight?
    
    @State private var analysisOverlay = AnalysisOverlay()
    
    @State private var elevation = Surface()
    
    @State private var buildingLayer = ArcGISSceneLayer(url: .buildingsService)

    init() {
        scene.baseSurface.addElevationSource(ArcGISTiledElevationSource(url: .elevationService))
        scene.addOperationalLayer(buildingLayer)
    }

    var body: some View {
        SceneView(scene: scene).onAppear {
            
        }
    }
}

extension URL {
    // URL of the elevation service - provides elevation component of the scene
    static var elevationService: URL {
        URL(string: "https://elevation3d.arcgis.com/arcgis/rest/services/WorldElevation3D/Terrain3D/ImageServer")!
    }
    
    // URL of the building service - provides builiding models
    static var buildingsService: URL {
        URL(string: "https://tiles.arcgis.com/tiles/z2tnIkrLQ2BRzr6P/arcgis/rest/services/Buildings_NewYork_v18/SceneServer/layers/0")!
    }
}
#Preview {
    ShowLineOfSightBetweenGeoelementsView()
}
