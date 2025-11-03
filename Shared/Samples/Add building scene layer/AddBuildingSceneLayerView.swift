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

struct AddBuildingSceneLayerView: View {
    /// A local scene with topographic basemap style and a tiled elevation source.
    @State private var scene: ArcGIS.Scene = {
        let scene = Scene(
            basemapStyle: .arcGISTopographic,
            viewingMode: .local
        )
        
        // Adds a surface.
        
        let elevationSource = ArcGISTiledElevationSource(
            url: URL(string: "https://elevation3d.arcgis.com/arcgis/rest/services/WorldElevation3D/Terrain3D/ImageServer")!
        )
        scene.baseSurface.addElevationSource(elevationSource)
        
        return scene
    }()
    
    /// A Boolean value that indicates if the full model of the building scene layer is visible or not.
    @State private var fullModelIsVisible = false
    
    /// The camera for zooming the local scene view to the building scene layer.
    @State private var camera: Camera? = Camera(
        location: Point(x: -13_045_109, y: 4_036_614, z: 511, spatialReference: .webMercator),
        heading: 343,
        pitch: 64,
        roll: 0
    )
    
    /// The overview sublayer which represents the exterior shell of the building.
    @State private var overviewSublayer: BuildingSublayer?
    
    /// The full model sublayer which contains all the features of the building.
    @State private var fullModelSublayer: BuildingSublayer?
    
    var body: some View {
        LocalSceneView(scene: scene, camera: $camera)
            .task {
                let buildingSceneLayer = BuildingSceneLayer(
                    url: URL(string: "https://arcgisruntime.maps.arcgis.com/home/item.html?id=e989757f7dbc460eae592eefa4562e07")!
                )
                
                // Sets the altitude offset of the building scene layer.
                // Upon first inspection of the model, it does not line up
                // with the global elevation layer perfectly. To fix this,
                // add an altitude offset to align the model with the
                // ground surface.
                buildingSceneLayer.altitudeOffset = 1
                
                try? await buildingSceneLayer.load()
                
                // Adds building scene layer to scene.
                scene.addOperationalLayer(buildingSceneLayer)
                
                // Get the overview and full model sublayers for the toggle.
                let sublayers = buildingSceneLayer.sublayers
                overviewSublayer = sublayers.first(where: { $0.name == "Overview" })
                fullModelSublayer = sublayers.first(where: { $0.name == "Full Model" })
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    // Shows the toggle when we have a valid full model
                    // sublayer since we need that for the toggle.
                    if fullModelSublayer != nil {
                        Toggle("Full Model", isOn: $fullModelIsVisible)
                            .toggleStyle(.button)
                    } else {
                        ProgressView()
                    }
                }
            }
            .onChange(of: fullModelIsVisible) {
                // Toggle the visibility of the full model sublayer.
                // This does not affect the 'isVisible' property of
                // individual sublayers within the full model.
                fullModelSublayer?.isVisible = fullModelIsVisible
                // The overview sublayer represents the exterior shell of
                // the building. The full model sublayer includes this
                // shell along with interior components. To avoid rendering
                // artifacts like z-fighting and redundant drawing, we
                // only display one at a time.
                overviewSublayer?.isVisible = !fullModelIsVisible
            }
    }
}

#Preview {
    AddBuildingSceneLayerView()
}
