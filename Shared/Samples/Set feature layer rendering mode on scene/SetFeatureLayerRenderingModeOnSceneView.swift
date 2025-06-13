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
    /// Scene that displays with dynamic rendering.
    @State private var dynamicScene = Scene()
    
    /// Scene that displays with static rendering.
    @State private var staticScene = Scene()
    
    /// A Boolean value indicating whether the scene views are currently zooming.
    @State private var isZooming = false
    
    /// The viewpoint for the scene.
    @State private var viewpoint: Viewpoint?
    
    /// A Boolean value indicating whether the scene is fully zoomed in.
    @State private var isZoomedIn = true
    
    
    init() {
        // The service feature tables using point, polygon, and polyline services.
        let featureTables: [ServiceFeatureTable] = [URL.pointTable, .polylineTable, .polygonTable].map(ServiceFeatureTable.init(url:))
        // Iterate through the feature tables and use them to set up feature layers.
        // Set the rendering mode for either dynamic or static rendering,
        // and add the feature layers to the scene.
        for featureTable in featureTables {
            // Set up the dynamic scene first.
            let dynamicFeatureLayer = FeatureLayer(featureTable: featureTable)
            dynamicFeatureLayer.renderingMode = .dynamic
            dynamicScene.addOperationalLayer(dynamicFeatureLayer)
            // Then set up the static scene using a clone of the dynamic feature layer.
            let staticFeatureLayer = dynamicFeatureLayer.clone()
            staticFeatureLayer.renderingMode = .static
            staticScene.addOperationalLayer(staticFeatureLayer)
        }
        staticScene.initialViewpoint = .zoomedOutViewpoint
        dynamicScene.initialViewpoint = .zoomedOutViewpoint
    }
    
    var body: some View {
        VStack(spacing: 0) {
            SceneViewReader { sceneViewProxy in
                SceneView(scene: staticScene)
                    .overlay(alignment: .top) {
                        Text("Static")
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(8)
                            .background(.regularMaterial, ignoresSafeAreaEdges: .horizontal)
                    }
                    .task(id: viewpoint) {
                        if let viewpoint = viewpoint {
                            await sceneViewProxy.setViewpoint(viewpoint, duration: 2)
                        }
                        isZooming = false
                    }
            }
            SceneViewReader { sceneViewProxy in
                SceneView(scene: dynamicScene)
                    .overlay(alignment: .top) {
                        Text("Dynamic")
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(8)
                            .background(.regularMaterial, ignoresSafeAreaEdges: .horizontal)
                    }
                    .task(id: viewpoint) {
                        if let viewpoint = viewpoint {
                            await sceneViewProxy.setViewpoint(viewpoint, duration: 2)
                        }
                        isZooming = false
                    }
            }
        }
        .onChange(of: isZooming) {
            guard isZooming else {
                isZoomedIn.toggle()
                return
            }
            viewpoint = isZoomedIn ? .zoomedInViewpoint : .zoomedOutViewpoint
        }
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button(isZoomedIn ? "Zoom Out" : "Zoom In") {
                    isZooming = true
                }
                .disabled(isZooming)
            }
        }
    }
}

private extension Viewpoint {
    /// Viewpoint for scene fully zoomed in.
    static var zoomedInViewpoint: Viewpoint {
        return Viewpoint(boundingGeometry: Camera.zoomedIn.location, camera: Camera.zoomedIn)
    }
    
    /// Viewpoint for scene fully zoomed out.
    static var zoomedOutViewpoint: Viewpoint {
        return Viewpoint(boundingGeometry: Camera.zoomedOut.location, camera: Camera.zoomedOut)
    }
}

private extension Camera {
    /// Camera set to zoom in on scene position at an angle.
    static var zoomedIn: Camera {
        Camera(
            lookingAt: Point(
                latitude: 34.395,
                longitude: -118.45
            ),
            distance: 2500,
            heading: 90,
            pitch: 75,
            roll: 0
        )
    }
    
    /// Camera set to zoom out on scene position without angle.
    static var zoomedOut: Camera {
        Camera(
            lookingAt: Point(
                latitude: 34.46,
                longitude: -118.37
            ),
            distance: 30000,
            heading: 0,
            pitch: 0,
            roll: 0
        )
    }
}

private extension URL {
    static var pointTable: URL {
        URL(string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/Energy/Geology/FeatureServer/0")!
    }
    
    static var polylineTable: URL {
        URL(string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/Energy/Geology/FeatureServer/8")!
    }
    
    static var polygonTable: URL {
        URL(string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/Energy/Geology/FeatureServer/9")!
    }
}

#Preview {
    SetFeatureLayerRenderingModeOnSceneView()
}
