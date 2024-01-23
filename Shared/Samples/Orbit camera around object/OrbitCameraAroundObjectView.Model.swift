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

extension OrbitCameraAroundObjectView {
    /// The view model for the sample.
    class Model: ObservableObject {
        // MARK: Properties
        
        /// A scene with an imagery basemap and world elevation surface.
        let scene: ArcGIS.Scene = {
            let scene = Scene(basemapStyle: .arcGISImagery)
            let elevationSource = ArcGISTiledElevationSource(url: .worldElevationService)
            scene.baseSurface.addElevationSource(elevationSource)
            return scene
        }()
        
        /// The graphics overlay for the plane graphic.
        let graphicsOverlay: GraphicsOverlay = {
            let graphicsOverlay = GraphicsOverlay()
            graphicsOverlay.sceneProperties.surfacePlacement = .relative
            
            let renderer = SimpleRenderer()
            renderer.sceneProperties.headingExpression = "[HEADING]"
            renderer.sceneProperties.pitchExpression = "[PITCH]"
            graphicsOverlay.renderer = renderer
            
            return graphicsOverlay
        }()
        
        /// The plane graphic created from a local URL.
        let planeGraphic: Graphic = {
            let planeSymbol = ModelSceneSymbol(url: .bristol, scale: 1)
            let planePosition = Point(x: 6.637, y: 45.399, z: 100, spatialReference: .wgs84)
            let planeGraphic = Graphic(
                geometry: planePosition,
                attributes: ["HEADING": 45.0, "PITCH": 0.0],
                symbol: planeSymbol
            )
            return planeGraphic
        }()
        
        /// The camera controller for the scene.
        let cameraController: OrbitGeoElementCameraController
        
        init() {
            graphicsOverlay.addGraphic(planeGraphic)
            
            // Create an orbit geo element camera controller targeted on the plane graphic.
            cameraController = OrbitGeoElementCameraController(
                target: planeGraphic,
                distance: 50
            )
            // Restrict the camera's heading to stay behind the plane.
            cameraController.minCameraHeadingOffset = -45
            cameraController.maxCameraHeadingOffset = 45
            
            // Restrict the camera to stay within 100 meters of the plane.
            cameraController.maxCameraDistance = 100
            
            // Position the plane a third from the top of the screen,
            // so it isn't covered by the settings sheet.
            cameraController.targetVerticalScreenFactor = 0.66
            
            // Don't pitch the camera when the plane pitches.
            cameraController.autoPitchIsEnabled = false
        }
        
        // MARK: Methods
        
        /// Moves the camera controller to center the plane in it's view.
        func moveToPlaneView() async throws {
            cameraController.cameraDistanceIsInteractive = true
            
            // Animate the camera to center the plane graphic with a
            // 45° pitch and facing forward (0° heading).
            if !cameraController.targetOffsetIsZero {
                // Unlock the camera pitch for the rotation animation.
                cameraController.minCameraPitchOffset = -180
                cameraController.maxCameraPitchOffset = 180
                
                let pitchDelta = pitchDelta(for: 45)
                cameraController.autoPitchIsEnabled = false
                
                await cameraController.moveCamera(
                    distanceDelta: 50 - cameraController.cameraDistance,
                    headingDelta: -cameraController.cameraHeadingOffset,
                    pitchDelta: pitchDelta,
                    duration: 1
                )
                _ = try await cameraController.setTargetOffsets(x: 0, y: 0, z: 0, duration: 1)
            }
            
            // Restrict the camera's pitch so it doesn't collide with the ground.
            cameraController.minCameraPitchOffset = 10
            cameraController.maxCameraPitchOffset = 100
            
            cameraController.minCameraDistance = 10
        }
        
        /// Moves the view of the camera controller to the cockpit of the plane.
        func moveToCockpit() async throws {
            cameraController.cameraDistanceIsInteractive = false
            cameraController.minCameraDistance = 0.1
            
            // Unlock the camera pitch for the rotation animation.
            cameraController.minCameraPitchOffset = -180
            cameraController.maxCameraPitchOffset = 180
            
            // Animate the camera to the cockpit, facing forward (0° heading),
            // and aligned with the horizon (90° pitch).
            _ = try await cameraController.setTargetOffsets(x: 0, y: -1.4, z: 1.3, duration: 1)
            await cameraController.moveCamera(
                distanceDelta: 0.1 - cameraController.cameraDistance,
                headingDelta: -cameraController.cameraHeadingOffset,
                pitchDelta: pitchDelta(for: 90),
                duration: 1
            )
            
            // Lock the camera pitch when the animation finishes.
            cameraController.minCameraPitchOffset = 90
            cameraController.maxCameraPitchOffset = 90
            cameraController.autoPitchIsEnabled = true
        }
        
        /// The camera pitch delta for a given angle and the current plane pitch.
        /// - Parameter angle: The angle in degrees.
        /// - Returns: The change in pitch.
        private func pitchDelta(for angle: Double) -> Double {
            let planePitch = planeGraphic.attributes["PITCH"] as? Double ?? 0
            let cameraPitchOffset = cameraController.cameraPitchOffset
            
            if cameraController.autoPitchIsEnabled {
                return angle - cameraPitchOffset
            } else {
                return angle + planePitch - cameraPitchOffset
            }
        }
    }
}

private extension OrbitGeoElementCameraController {
    /// A Boolean value indicating whether all the target offset values are zero.
    var targetOffsetIsZero: Bool {
        return [targetOffsetX, targetOffsetY, targetOffsetZ].allSatisfy(\.isZero)
    }
}

private extension URL {
    /// A URL to the local Bristol 3D model files.
    static var bristol: URL {
        Bundle.main.url(forResource: "Bristol", withExtension: "dae", subdirectory: "Bristol")!
    }
    
    /// A world elevation service from Terrain3D ArcGIS REST service.
    static var worldElevationService: URL {
        URL(string: "https://elevation3d.arcgis.com/arcgis/rest/services/WorldElevation3D/Terrain3D/ImageServer")!
    }
}
