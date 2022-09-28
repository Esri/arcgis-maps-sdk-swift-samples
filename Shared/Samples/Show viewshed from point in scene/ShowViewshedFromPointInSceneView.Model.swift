// Copyright 2022 Esri
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

extension ShowViewshedFromPointInSceneView {
    class Model: ObservableObject {
        /// A scene with imagery basemap style.
        let scene: ArcGIS.Scene
        
        /// The location viewshed used in the sample.
        var viewshed = LocationViewshed(
            location: Point(x: -4.50, y: 48.4, z: 100, spatialReference: .wgs84),
            heading: 20,
            pitch: 70,
            horizontalAngle: 45,
            verticalAngle: 90,
            minDistance: 50,
            maxDistance: 1000
        )!
        
        /// An analysis overlay that contains a location viewshed analysis.
        var analysisOverlay: AnalysisOverlay
        
        init() {
            analysisOverlay = AnalysisOverlay(analyses: [viewshed])
            scene = Self.makeScene()
        }
        
        /// Makes a scene.
        private static func makeScene() -> ArcGIS.Scene {
            // Creates a scene.
            let scene = Scene(basemapStyle: .arcGISImageryStandard)
            
            // Sets the initial viewpoint of the scene.
            let camera = Camera(
                lookAtPoint: Point(x: -4.50, y: 48.4, z: 100.0, spatialReference: .wgs84),
                distance: 200,
                heading: 20,
                pitch: 70,
                roll: 0
            )
            scene.initialViewpoint = Viewpoint(targetExtent: camera.location, camera: camera)
            
            // Creates a surface.
            let surface = Surface()
            
            // Creates and adds a tiled elevation source.
            let elevationSource = ArcGISTiledElevationSource(url: .worldElevationService)
            surface.addElevationSource(elevationSource)
            
            // Sets the surface to the scene's base surface.
            scene.baseSurface = surface
            
            // Creates and adds a scene layer for buildings in Brest, France.
            let buildingsLayer = ArcGISSceneLayer(url: .brestBuildingsLayer)
            scene.addOperationalLayer(buildingsLayer)
            
            return scene
        }
    }
}

private extension URL {
    /// The URL for the world elevation service.
    static var worldElevationService: URL {
        URL(string: "https://elevation3d.arcgis.com/arcgis/rest/services/WorldElevation3D/Terrain3D/ImageServer")!
    }
    
    /// The URL for the 3D buildings layer in Brest, France.
    static var brestBuildingsLayer: URL {
        URL(string: "https://tiles.arcgis.com/tiles/P3ePLMYs2RVChkJx/arcgis/rest/services/Buildings_Brest/SceneServer/layers/0")!
    }
}
