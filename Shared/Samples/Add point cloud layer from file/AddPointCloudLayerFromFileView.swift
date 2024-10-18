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

struct AddPointCloudLayerFromFileView: View {
    /// A scene with a point cloud layer of Balboa Park, San Diego, CA.
    @State private var scene: ArcGIS.Scene = {
        let scene = Scene(basemapStyle: .arcGISImagery)
        
        // Creates the point cloud layer and adds it to the scene.
        let pointCloudLayer = PointCloudLayer(url: .sanDiegoNorthBalboaPointCloud)
        scene.addOperationalLayer(pointCloudLayer)
        
        // Adds an elevation source to display elevation on the scene's surface.
        let elevationSource = ArcGISTiledElevationSource(url: .worldElevationService)
        scene.baseSurface.addElevationSource(elevationSource)
        
        // Initially centers the scene's camera on the point cloud layer.
        let camera = Camera(
            latitude: 32.720195,
            longitude: -117.155593,
            altitude: 1050,
            heading: 23,
            pitch: 70,
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
    /// The URL to the local scene layer package with point cloud data of Balboa Park, San Diego, CA.
    static var sanDiegoNorthBalboaPointCloud: URL {
        Bundle.main.url(
            forResource: "sandiego-north-balboa-pointcloud",
            withExtension: "slpk"
        )!
    }
    
    /// A URL to the Terrain3D image server on ArcGIS REST.
    static var worldElevationService: URL {
        URL(string: "https://elevation3d.arcgis.com/arcgis/rest/services/WorldElevation3D/Terrain3D/ImageServer")!
    }
}
