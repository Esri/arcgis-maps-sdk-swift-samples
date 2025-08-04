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

struct SetKMLGroundOverlayPropertiesView: View {
    /// A scene with an imagery basemap.
    @State private var scene = Scene(basemapStyle: .arcGISImagery)
    /// A KML ground overlay for making a KML dataset.
    @State private var overlay: KMLGroundOverlay = {
        // Create a geometry for the ground overlay.
        let overlayGeometry = Envelope(xMin: -123.066227926904, yMin: 44.04736963555683, xMax: -123.0796942287304, yMax: 44.03878298600624, spatialReference: .wgs84)
        // Create a KML icon for the overlay image.
        let imageURL = URL(string: "https://libapps.s3.amazonaws.com/accounts/55937/images/1944.jpg")!
        let overlayImage = KMLIcon(url: imageURL)
        let overlay = KMLGroundOverlay(geometry: overlayGeometry, icon: overlayImage)!
        // Set the rotation of the ground overlay.
        overlay.rotation = -3.046024799346924
        return overlay
    }()
    /// The current viewpoint of the scene view.
    @State private var viewpoint: Viewpoint?
    /// The opacity slider value.
    @State private var opacity: Double = 1
    
    var body: some View {
        SceneView(scene: scene, viewpoint: viewpoint)
            .task {
                // Create a KML dataset with the ground overlay as the root node.
                let dataset = KMLDataset(rootNode: overlay)
                // Create a KML layer for the scene view.
                let layer = KMLLayer(dataset: dataset)
                // Add the layer to the scene.
                scene.addOperationalLayer(layer)
                // Move the viewpoint to the ground overlay.
                let targetExtent = overlay.geometry as! Envelope
                let camera = Camera(lookingAt: targetExtent.center, distance: 1250, heading: 45, pitch: 60, roll: 0)
                viewpoint = Viewpoint(boundingGeometry: targetExtent, camera: camera)
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    HStack {
                        Slider(value: $opacity, in: 0.0...1.0, step: 0.01)
                        VStack {
                            Text("Opacity")
                            Text(opacity, format: .percent.precision(.fractionLength(0)))
                        }
                        .onChange(of: opacity) {
                            // Change the color of the overlay according to the slider's value.
                            let alpha = CGFloat(opacity)
                            overlay.color = UIColor.black.withAlphaComponent(alpha)
                        }
                    }
                }
            }
    }
}

#Preview {
    SetKMLGroundOverlayPropertiesView()
}
