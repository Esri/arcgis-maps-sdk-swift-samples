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
    @State private var dynamicScene: ArcGIS.Scene = {
        let scene = Scene()
        scene.initialViewpoint = .zoomedOut
        return scene
    }()
    
    /// Scene that displays with static rendering.
    @State private var staticScene: ArcGIS.Scene = {
        let scene = Scene()
        scene.initialViewpoint = .zoomedOut
        return scene
    }()
    
    /// A Boolean value indicating whether the scene views are currently zooming.
    @State private var isZooming = false
    
    /// The viewpoint for the scene.
    @State private var viewpoint: Viewpoint?
    
    /// A Boolean value indicating whether the scene is fully zoomed in.
    @State private var isZoomedIn = true
    
    /// Creates service feature tables using point, polygon, and polyline services
    let featureTables: [ServiceFeatureTable] = [
        ServiceFeatureTable(url: .pointTable),
        ServiceFeatureTable(url: .polylineTable),
        ServiceFeatureTable(url: .polygonTable)
    ]
    
    init() {
        /// Iterate through the feature tables and use them to setup a feature layers. Set the rendering mode
        /// for either dynamic or static rendering and add the feature layer to the scene.
        for featureTable in featureTables {
            // Setup the dynamic scene first.
            let dynamicFeatureLayer = FeatureLayer(featureTable: featureTable)
            dynamicFeatureLayer.renderingMode = .dynamic
            dynamicScene.addOperationalLayer(dynamicFeatureLayer)
            // Then setup the static scene using a clone dynamic feature layer.
            let staticFeatureLayer = dynamicFeatureLayer.clone()
            staticFeatureLayer.renderingMode = .static
            staticScene.addOperationalLayer(staticFeatureLayer)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            SceneView(scene: staticScene, viewpoint: viewpoint)
                .overlay(alignment: .top) {
                    Text("Static")
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(8)
                        .background(.regularMaterial, ignoresSafeAreaEdges: .horizontal)
                }
                .task(id: viewpoint) { isZooming = false }
            SceneView(scene: dynamicScene, viewpoint: viewpoint)
                .overlay(alignment: .top) {
                    Text("Dynamic")
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(8)
                        .background(.regularMaterial, ignoresSafeAreaEdges: .horizontal)
                }
                .task(id: viewpoint) { isZooming = false }
        }
        .onChange(of: isZooming) {
            guard isZooming else {
                isZoomedIn.toggle()
                return
            }
            viewpoint = isZoomedIn ? .zoomedIn : .zoomedOut
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
    static var zoomedIn: Viewpoint {
        Viewpoint(
            center: Point(
                x: -118.45,
                y: 34.395,
                spatialReference: .wgs84
            ),
            scale: 650000,
            rotation: 0
        )
    }
    
    /// Viewpoint for scene fully zoomed out.
    static var zoomedOut: Viewpoint {
        Viewpoint(
            center: Point(
                x: -118.37,
                y: 34.46,
                spatialReference: .wgs84
            ),
            scale: 50000,
            rotation: 90
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
