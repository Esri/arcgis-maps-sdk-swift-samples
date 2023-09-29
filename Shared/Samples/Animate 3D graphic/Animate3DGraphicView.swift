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

struct Animate3DGraphicView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    var body: some View {
        SceneView(
            scene: model.scene,
            cameraController: model.cameraController,
            graphicsOverlays: [model.sceneGraphicsOverlay]
        )
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    /// The mission selection menu.
                    Menu("Mission") {
                        Picker("Mission", selection: $model.animation.mission) {
                            ForEach(Mission.allCases, id: \.self) { mission in
                                Text(mission.label)
                            }
                            .pickerStyle(.inline)
                        }
                        .onChange(of: model.animation.mission) { _ in
                            // Set graphics to the starting position for the new mission.
                            model.updatePositions()
                        }
                    }
                    
                    /// The play and pause button.
                    Button {
                        model.animation.isPlaying ? model.animation.stop() : model.startAnimation()
                    } label: {
                        Image(systemName: model.animation.isPlaying ? "pause.fill" : "play.fill")
                    }
                }
            }
            .onDisappear {
                model.animation.stop()
            }
    }
}

private extension Animate3DGraphicView {
    /// The view model for the sample.
    class Model: ObservableObject {
        /// A scene with an imagery basemap and a world elevation source.
        let scene: ArcGIS.Scene = {
            let scene = Scene(basemapStyle: .arcGISImagery)
            
            // Set the scene's base surface with an elevation source.
            let surface = Surface()
            let elevationSource = ArcGISTiledElevationSource(url: .worldElevationService)
            surface.addElevationSource(elevationSource)
            scene.baseSurface = surface
            
            return scene
        }()
        
        /// The camera controller targeted on the plane graphics.
        lazy private(set) var cameraController: OrbitGeoElementCameraController = {
            // Create camera controller by with plane graphic and the distance to keep from it.
            let cameraController = OrbitGeoElementCameraController(target: planeGraphic, distance: 1000)
            
            // Set camera to align its heading with the model.
            cameraController.autoHeadingIsEnabled = true
            
            // Keep the camera still while the model pitches or rolls.
            cameraController.autoPitchIsEnabled = false
            cameraController.autoRollIsEnabled = false
            
            // Set the min and max distance values between the model and the camera.
            cameraController.minCameraDistance = 500
            cameraController.maxCameraDistance = 8000
            
            return cameraController
        }()
        
        /// The graphics overlay for the plane graphic in the scene.
        lazy private(set) var sceneGraphicsOverlay: GraphicsOverlay = {
            // Create a graphics overlay and add the plane graphic.
            let graphicsOverlay = GraphicsOverlay()
            graphicsOverlay.sceneProperties.surfacePlacement = .absolute
            graphicsOverlay.addGraphic(planeGraphic)

            
            // Create a renderer and set its expressions.
            let renderer = SimpleRenderer()
            renderer.sceneProperties.headingExpression = "[HEADING]"
            renderer.sceneProperties.pitchExpression = "[PITCH]"
            renderer.sceneProperties.rollExpression = "[ROLL]"
            graphicsOverlay.renderer = renderer
                        
            return graphicsOverlay
        }()
        
        /// The graphic of the plane model.
        private let planeGraphic: Graphic = {
            // Create the model symbol for the plane using a URL.
            let planeModelSymbol = ModelSceneSymbol(url: .bristol, scale: 20)
            planeModelSymbol.anchorPosition = .center

            // Create graphic for the symbol.
            return Graphic(symbol: planeModelSymbol)
        }()
        
        /// The animation for the sample.
        @Published var animation = Animation()
        
        init() {
            // Set graphics to starting their starting position.
            updatePositions()
        }
        
        /// Starts a new animation by creating a timer used to move the graphics.
        func startAnimation() {
            // Stop previous on going animation.
            animation.stop()
            animation.isPlaying = true
            
            // Create a new timer to loop through the animation frames.
            let interval = 1 / Double(animation.speed)
            animation.timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                // Update the graphics' position for each frame.
                self?.updatePositions()
                self?.animation.nextFrame()
            }
        }

        /// Updates the position of the plane graphic and the map.
        func updatePositions() {
            // Get the current frame of the animation.
            guard let frame = animation.currentFrame else {
                print("Update failed")
                return
            }
            
            // Update the plane graphic position and attribute using the frame.
            planeGraphic.geometry = frame.position
            planeGraphic.setAttributeValue(frame.heading.value, forKey: "HEADING")
            planeGraphic.setAttributeValue(frame.pitch.value, forKey: "PITCH")
            planeGraphic.setAttributeValue(frame.roll.value, forKey: "ROLL")
            
            // Update the map.
        }
    }
    
    /// A struct containing data for an animation.
    struct Animation {
        /// The timer for the animation used to loop through the animation frames.
        var timer: Timer?
        
        /// The speed of the animation used to set the timer's time interval.
        var speed: Int = 50
        
        /// The current mission selection of the animation.
        var mission: Mission = .grandCanyon {
            didSet {
                // Reset the animation and load the new frames when the mission changes.
                if oldValue != mission {
                    reset()
                    loadFrames()
                }
            }
        }
        
        /// A Boolean that indicates whether the animation is current playing.
        var isPlaying = false
        
        /// The current frame of the animation.
        var currentFrame: Frame? {
            if currentFrameIndex < frames.count {
                return frames[currentFrameIndex]
            } else {
                return nil
            }
        }
        
        /// The all frames of the animation.
        private var frames: [Frame] = []
        
        /// The index of the current frame in the frames list.
        private var currentFrameIndex = 0
        
        init() {
            // Load the frames for the default mission on init.
            loadFrames()
        }
        
        /// Stops the animation by invalidating the timer.
        mutating func stop() {
            timer?.invalidate()
            isPlaying = false
        }
        
        /// Increments the animation to the next frame.
        mutating func nextFrame() {
            if currentFrameIndex >= frames.count {
                // Reset the animation when it has reached the end.
                reset()
            } else {
                // Move the index to point to the next frame.
                currentFrameIndex += 1
            }
        }
        
        /// Resets the animation to the beginning in an unplayed state.
        private mutating func reset() {
            stop()
            currentFrameIndex = 0
        }
        
        /// Loads the frames of the current mission using data found in a CSV file.
        private mutating func loadFrames() {
            // Get the path of the file in the bundle using the mission name.
            guard let path = Bundle.main.path(
                forResource: mission.label.replacingOccurrences(of: " ", with: ""),
                ofType: "csv"
            ) else { return }
            
            // Get the content of the file using the path.
            guard let content = try? String(contentsOfFile: path) else { return }
            
            // Split content by line into an array.
            let lines = content.split(whereSeparator: \.isNewline)
            
            // Create a frame for each line.
            frames = lines.map { line in
                // Spilt the line of numbers into an array.
                let details = line.split(separator: ",")
                let position = Point(
                    x: Double(details[0])!,
                    y: Double(details[1])!,
                    z: Double(details[2])!,
                    spatialReference: .wgs84
                )
                return Frame(
                    position: position,
                    heading: Measurement(value: Double(details[3])!, unit: .degrees),
                    pitch: Measurement(value: Double(details[4])!, unit: .degrees),
                    roll: Measurement(value: Double(details[5])!, unit: .degrees)
                )
            }
        }
    }
    
    /// A struct containing the location data for a single frame in a 3D animation.
    struct Frame {
        let position: Point
        let heading: Measurement<UnitAngle>
        let pitch: Measurement<UnitAngle>
        let roll: Measurement<UnitAngle>
        
        var altitude: Measurement<UnitLength> {
            Measurement(value: position.z ?? 0, unit: .meters)
        }
    }
    
    /// An enumeration of the different missions selections available in this sample.
    enum Mission: CaseIterable {
        case grandCanyon, hawaii, pyrenees, snowdon
        
        /// A human-readable label of the mission name.
        var label: String {
            switch self {
            case .grandCanyon: "Grand Canyon"
            case .hawaii: "Hawaii"
            case .pyrenees: "Pyrenees"
            case .snowdon: "Snowdon"
            }
        }
    }
}

private extension URL {
    /// A URL to world elevation service from Terrain3D ArcGIS REST service.
    static var worldElevationService: URL {
        URL(string: "https://elevation3d.arcgis.com/arcgis/rest/services/WorldElevation3D/Terrain3D/ImageServer")!
    }
    
    /// A URL to the local Bristol 3D model files.
    static var bristol: URL {
        Bundle.main.url(forResource: "Bristol", withExtension: "dae", subdirectory: "Bristol")!
    }
}
