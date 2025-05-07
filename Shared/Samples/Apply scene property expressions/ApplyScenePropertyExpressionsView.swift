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

struct ApplyScenePropertyExpressionsView: View {
    /// The scene that displays in the scene view.
    @State private var scene: ArcGIS.Scene = {
        let scene = ArcGIS.Scene(basemapStyle: .arcGISImageryStandard)
        
        // Give the scene an initial viewpoint.
        let point = Point(x: 83.9, y: 28.4, z: 1000, spatialReference: .wgs84)
        scene.initialViewpoint = Viewpoint(
            latitude: point.y,
            longitude: point.x,
            scale: 0,
            camera: .init(lookingAt: point, distance: 1000, heading: 0, pitch: 50, roll: 0)
        )
        
        return scene
    }()
    
    /// The graphics overlay that we will display a cone graphic in.
    @State private var graphicsOverlay = {
        let overlay = GraphicsOverlay()
        overlay.sceneProperties.surfacePlacement = .relative
        
        let renderer = SimpleRenderer()
        renderer.sceneProperties.headingExpression = "[HEADING]"
        renderer.sceneProperties.pitchExpression = "[PITCH]"
        overlay.renderer = renderer
        
        let symbol = SimpleMarkerSceneSymbol.cone(
            color: .red,
            diameter: 100,
            height: 100
        )
        
        let graphic = Graphic(
            geometry: Point(x: 83.9, y: 28.42, z: 200, spatialReference: .wgs84),
            attributes: [
                "HEADING": 180.0,
                "PITCH": 45.0
            ],
            symbol: symbol
        )
        overlay.addGraphic(graphic)
        return overlay
    }()
    
    /// A boolean value indicating if the settings plane is displayed.
    @State private var isSettingsPresented = false
    
    /// The heading of the cone.
    @State private var heading = 0.0
    
    /// The pitch of the cone.
    @State private var pitch = 0.0
    
    /// The cone graphic.
    private var coneGraphic: Graphic {
        graphicsOverlay.graphics[0]
    }
    
    var body: some View {
        SceneView(
            scene: scene,
            graphicsOverlays: [graphicsOverlay]
        )
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button {
                    isSettingsPresented = true
                } label: {
                    Text("Settings")
                }
            }
        }
        .popover(isPresented: $isSettingsPresented, arrowEdge: .bottom) {
            Form {
                Section {
                    LabeledContent("Heading", value: heading, format: .number)
                    Slider(value: $heading, in: 0...360, step: 1)
                }
                Section {
                    LabeledContent("Pitch", value: pitch, format: .number)
                    Slider(value: $pitch, in: 0...180, step: 1)
                }
            }
            .presentationDetents([.medium])
            .frame(idealWidth: 320, idealHeight: 380)
        }
        .onAppear {
            heading = coneGraphic.attributes["HEADING"] as? Double ?? 0
            pitch = coneGraphic.attributes["PITCH"] as? Double ?? 0
        }
        .onChange(of: heading) { coneGraphic.setAttributeValue(heading, forKey: "HEADING") }
        .onChange(of: pitch) { coneGraphic.setAttributeValue(pitch, forKey: "PITCH") }
    }
}

#Preview {
    ApplyScenePropertyExpressionsView()
}
