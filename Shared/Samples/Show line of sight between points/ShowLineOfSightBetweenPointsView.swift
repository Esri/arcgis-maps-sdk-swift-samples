// Copyright 2023 Esri
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

import SwiftUI
import ArcGIS

struct ShowLineOfSightBetweenPointsView: View {
    /// A scene with an imagery basemap and centered on mountains in Chile.
    @State private var scene: ArcGIS.Scene = {
        // Creates a scene.
        let scene = Scene(basemapStyle: .arcGISImagery)
        
        // Add elevation source to the base surface of the scene with the service URL.
        let elevationSource = ArcGISTiledElevationSource(url: .worldElevationService)
        scene.baseSurface.addElevationSource(elevationSource)
        
        // Set scene to the viewpoint specified by the camera position.
        let point = Point(x: -73.0870, y: -49.3460, z: 5046, spatialReference: .wgs84)
        let camera = Camera(location: point, heading: 11, pitch: 62, roll: 0)
        scene.initialViewpoint = Viewpoint(boundingGeometry: point, camera: camera)
        
        return scene
    }()
    
    /// The analysis overlay for the line of sight analysis.
    @State private var analysisOverlay = AnalysisOverlay()
    
    /// The line of sight analysis.
    @State private var lineOfSight: LocationLineOfSight?
    
    /// A Boolean value indicating whether to show the target instructions.
    @State private var shouldShowTargetInstruction = false
    
    var body: some View {
        SceneView(scene: scene, analysisOverlays: [analysisOverlay])
            .onSingleTapGesture { _, scenePoint in
                // User tapped to place line of sight observer.
                guard let scenePoint else { return }
                if lineOfSight == nil {
                    // Create and set initial line of sight analysis with tapped scene point.
                    lineOfSight = LocationLineOfSight(observerLocation: scenePoint, targetLocation: scenePoint)
                    analysisOverlay.addAnalysis(lineOfSight!)
                    shouldShowTargetInstruction = true
                } else {
                    // Update the observer location.
                    lineOfSight?.observerLocation = scenePoint
                }
            }
            .onLongPressGesture {  _, scenePoint in
                // Update the target location on long press.
                guard let scenePoint else { return }
                lineOfSight?.targetLocation = scenePoint
            }
            .overlay(alignment: .top) {
                // Instruction texts.
                VStack {
                    Text("Tap on the map to set the observer location.")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(.thinMaterial, ignoresSafeAreaEdges: .horizontal)
                    
                    Text("Tap and hold to set the line of sight target.")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(.thinMaterial, ignoresSafeAreaEdges: .horizontal)
                        .padding(.top, -8)
                        .opacity(shouldShowTargetInstruction ? 1 : 0)
                }
            }
    }
}

private extension URL {
    /// A world elevation service from Terrain3D ArcGIS REST service.
    static var worldElevationService: URL {
        URL(string: "https://elevation3d.arcgis.com/arcgis/rest/services/WorldElevation3D/Terrain3D/ImageServer")!
    }
}

#Preview {
    ShowLineOfSightBetweenPointsView()
}
