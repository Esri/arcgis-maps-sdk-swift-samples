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

import ArcGIS
import SwiftUI

struct GetElevationAtPointOnSurfaceView: View {
    /// The view model for the sample.
    @State private var scene: ArcGIS.Scene = {
        let scene = Scene(basemapStyle: .arcGISImagery)
        
        // Sets the initial viewpoint of the scene to northern Nepal.
        scene.initialViewpoint = Viewpoint(
            latitude: .nan,
            longitude: .nan,
            scale: .nan,
            camera: Camera(
                latitude: 28.42,
                longitude: 83.9,
                altitude: 1e4,
                heading: 10,
                pitch: 80,
                roll: 0
            )
        )
        
        // Creates a surface.
        let surface = Surface()
        
        // Adds the elevation source to the surface.
        surface.addElevationSource(.worldElevationSource())
        
        // Sets the surface to the scene's base surface.
        scene.baseSurface = surface
        return scene
    }()
    
    /// The location callout placement.
    @State private var calloutPlacement: CalloutPlacement?
    
    /// The screen point where to get the base surface location.
    @State private var screenPoint: CGPoint?
    
    /// The scene point where the scene was tapped.
    @State private var scenePoint: Point?
    
    /// The surface elevation of the tapped point.
    @State private var elevation: Double?
    
    var body: some View {
        SceneViewReader { sceneViewProxy in
            SceneView(scene: scene)
                .onSingleTapGesture { screenPoint, scenePoint in
                    self.screenPoint = screenPoint
                    self.scenePoint = scenePoint
                }
                .callout(placement: $calloutPlacement.animation(.default.speed(2))) { _ in
                    VStack(alignment: .leading) {
                        Text("Elevation")
                            .font(.headline)
                        let elevationText = if let elevation {
                            Text(
                                Measurement<UnitLength>(
                                    value: elevation,
                                    unit: .meters
                                ),
                                format: .measurement(
                                    width: .abbreviated,
                                    numberFormatStyle: .number.precision(.fractionLength(3))
                                )
                            )
                        } else {
                            Text("Invalid Elevation")
                        }
                        elevationText
                            .font(.callout)
                    }
                    .padding(5)
                }
                .task(id: scenePoint) {
                    guard let scenePoint, let screenPoint else { return }
                    if calloutPlacement == nil {
                        // Converts the tapped screen point into a point on the surface.
                        guard let relativeSurfacePoint = sceneViewProxy.baseSurfaceLocation(fromScreenPoint: screenPoint) else { return }
                        // Gets the elevation from the tap location.
                        elevation = await elevation(at: relativeSurfacePoint)
                        // Shows the callout at the tapped location.
                        calloutPlacement = CalloutPlacement.location(scenePoint)
                    } else {
                        // Hides the callout.
                        calloutPlacement = nil
                    }
                }
        }
    }
    
    /// Gets the elevation at the surface point.
    /// - Parameter surfacePoint: A geographical location on the base surface
    /// in the same spatial reference as the scene view.
    /// - Returns: The elevation in meters.
    private func elevation(at surfacePoint: Point) async -> Double? {
        try? await scene.baseSurface.elevation(at: surfacePoint)
    }
}

private extension ElevationSource {
    /// A tiled elevation source that provides global elevation.
    static func worldElevationSource() -> ElevationSource {
        return ArcGISTiledElevationSource(
            url: URL(string: "https://elevation3d.arcgis.com/arcgis/rest/services/WorldElevation3D/Terrain3D/ImageServer")!
        )
    }
}

#Preview {
    GetElevationAtPointOnSurfaceView()
}
