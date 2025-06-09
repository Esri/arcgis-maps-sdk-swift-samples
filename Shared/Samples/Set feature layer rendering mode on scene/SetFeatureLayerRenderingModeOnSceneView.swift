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
    /// The error shown in the error alert.
    @State private var error: Error?
    
    @State private var dynamicScene: ArcGIS.Scene = {
        let scene = Scene()
        var zoomedOutCamera = Camera(
            lookingAt:
                Point(
                    x: -118.37,
                    y: 34.46,
                    spatialReference: .wgs84
                ),
            distance: 65000,
            heading: 0,
            pitch: 0,
            roll: 0
        )
        scene.initialViewpoint = Viewpoint(
            boundingGeometry: zoomedOutCamera.location,
            camera: zoomedOutCamera
        )
        return scene
    }()
    
    @State private var staticScene: ArcGIS.Scene = {
        let scene = Scene()
        var zoomedOutCamera = Camera(
            lookingAt:
                Point(
                    x: -118.37,
                    y: 34.46,
                    spatialReference: .wgs84
                ),
            distance: 65000,
            heading: 0,
            pitch: 0,
            roll: 0
        )
        scene.initialViewpoint = Viewpoint(boundingGeometry: zoomedOutCamera.location, camera: zoomedOutCamera)
        return scene
    }()
    
    /// A Boolean value indicating whether the map views are currently zooming.
    @State private var isZooming = false
    
    @State private var viewpoint: Viewpoint?
    
    @State private var isZoomedIn = true
    
    init() {
        // create service feature tables using point, polygon, and polyline services
        let pointTable = ServiceFeatureTable(
            url: URL(
                string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/Energy/Geology/FeatureServer/0"
            )!
        )
        
        let polylineTable = ServiceFeatureTable(
            url: URL(
                string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/Energy/Geology/FeatureServer/8"
            )!
        )
        
        let polygonTable = ServiceFeatureTable(
            url: URL(
                string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/Energy/Geology/FeatureServer/9"
            )!
        )
        
        for featureTable in [polygonTable, polylineTable, pointTable] {
            let dynamicFeatureLayer = FeatureLayer(featureTable: featureTable)
            dynamicFeatureLayer.renderingMode = .dynamic
            dynamicScene.addOperationalLayer(dynamicFeatureLayer)
            let staticFeatureLayer = dynamicFeatureLayer.clone()
            staticFeatureLayer.renderingMode = .static
            staticScene.addOperationalLayer(staticFeatureLayer)
        }
        viewpoint = .zoomedOut
    }
    
    var body: some View {
        VStack(spacing: 0) {
            SceneView(scene: staticScene, viewpoint: viewpoint)
                .overlay(alignment: .top) {
                    Text("Static")
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(8)
                        .background(
                            .regularMaterial, ignoresSafeAreaEdges: .horizontal)
                }
                .task(id: viewpoint) {
                    guard let viewpoint else { return }
                    staticScene.initialViewpoint = viewpoint
                    isZooming = false
                }
            SceneView(scene: dynamicScene, viewpoint: viewpoint)
                .overlay(alignment: .top) {
                    Text("Dynamic")
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(8)
                        .background(.regularMaterial, ignoresSafeAreaEdges: .horizontal)
                }
                .task(id: viewpoint) {
                    guard let viewpoint else { return }
                    dynamicScene.initialViewpoint = viewpoint
                    isZooming = false
                }
        }.onChange(of: isZooming) {
            if isZooming {
                // Zooming began.
                viewpoint = isZoomedIn ? .zoomedOut : .zoomedIn
            } else {
                // Zooming ended.
                isZoomedIn.toggle()
            }
        }
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button {
                    isZooming = true
                } label: {
                    isZoomedIn ? Text("Zoom Out") : Text("Zoom In")
                }
                .disabled(isZooming)
            }
        }
    }
}

private extension Viewpoint {
    static var zoomedIn: Viewpoint {
        Viewpoint(
            center: Point(
                x: -118.45,
                y: 34.395,
                spatialReference: .wgs84),
            scale: 650000,
            rotation: 0
        )
    }
    
    static var zoomedOut: Viewpoint {
        Viewpoint(
            center: Point(
                x: -118.37,
                y: 34.46,
                spatialReference: .wgs84
            ),
            scale: 650000,
            rotation: 90
        )
    }
}

#Preview {
    SetFeatureLayerRenderingModeOnSceneView()
}
