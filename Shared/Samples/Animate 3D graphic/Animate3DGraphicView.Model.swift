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

extension Animate3DGraphicView {
    /// The view model for the sample.
    class Model: ObservableObject {
        // MARK: Scene Properties
        
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
        
        /// The camera controller set to follow the plane graphic.
        private(set) lazy var cameraController: OrbitGeoElementCameraController = {
            // Create camera controller with the plane graphic and the distance to keep from it.
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
        private(set) lazy var sceneGraphicsOverlay: GraphicsOverlay = {
            // Create a graphics overlay and add the plane graphic.
            let graphicsOverlay = GraphicsOverlay(graphics: [planeGraphic])
            graphicsOverlay.sceneProperties.surfacePlacement = .absolute
            
            // Create a renderer to set its expressions.
            let renderer = SimpleRenderer()
            renderer.sceneProperties.headingExpression = "[HEADING]"
            renderer.sceneProperties.pitchExpression = "[PITCH]"
            renderer.sceneProperties.rollExpression = "[ROLL]"
            graphicsOverlay.renderer = renderer
            
            return graphicsOverlay
        }()
        
        /// The plane model scene symbol graphic.
        private let planeGraphic: Graphic = {
            // Create the model symbol for the plane using a URL.
            let planeModelSymbol = ModelSceneSymbol(url: .bristol, scale: 20)
            planeModelSymbol.anchorPosition = .center
            
            // Create graphic for the symbol.
            return Graphic(symbol: planeModelSymbol)
        }()
        
        // MARK: Map Properties
        
        /// A map with an streets basemap used to display the location of the plane.
        let map = Map(basemapStyle: .arcGISStreets)
        
        /// The graphics overlay for the graphics on the map view.
        private(set) lazy var mapGraphicsOverlay: GraphicsOverlay = {
            let graphicsOverlay = GraphicsOverlay(graphics: [routeGraphic, triangleGraphic])
            
            // Create a render to set the rotation expression.
            let renderer = SimpleRenderer()
            renderer.rotationExpression = "[ANGLE]"
            graphicsOverlay.renderer = renderer
            
            return graphicsOverlay
        }()
        
        /// The route line graphic.
        private let routeGraphic: Graphic = {
            let lineSymbol = SimpleLineSymbol(style: .solid, color: .blue, width: 1)
            return Graphic(symbol: lineSymbol)
        }()
        
        /// The triangle graphic used to represent the plane on the map.
        private let triangleGraphic: Graphic = {
            let triangleSymbol = SimpleMarkerSymbol(style: .triangle, color: .red, size: 10)
            return Graphic(symbol: triangleSymbol)
        }()
        
        /// The current viewpoint of the map view.
        private(set) var viewpoint: Viewpoint?
        
        /// The current mission selection.
        @Published var mission: Mission = .grandCanyon {
            didSet {
                if oldValue != mission {
                    updateMission()
                }
            }
        }
        
        /// The animation for the sample.
        @Published var animation = Animation()
        
        init() {
            updateMission()
        }
        
        // MARK: Methods
        
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
        
        /// Updates everything needed to switch to a new mission.
        private func updateMission() {
            // Reset the animation to the beginning
            animation.reset()
            
            // Load the frames of the new mission
            animation.loadFrames(for: mission.label.replacingOccurrences(of: " ", with: ""))
            
            // Create a polyline for the route using the position in each frame.
            let points = animation.frames.map { $0.position }
            routeGraphic.geometry = Polyline(points: points)
            
            // Set positions to the starting frame of the mission.
            updatePositions()
        }
        
        /// Updates the positions of the graphics and the viewpoint using a frame.
        private func updatePositions() {
            // Get the current frame of the animation.
            let frame = animation.currentFrame
            
            // Update the plane graphic's position and attributes using the frame.
            planeGraphic.geometry = frame.position
            planeGraphic.setAttributeValue(frame.heading.value, forKey: "HEADING")
            planeGraphic.setAttributeValue(frame.pitch.value, forKey: "PITCH")
            planeGraphic.setAttributeValue(frame.roll.value, forKey: "ROLL")
            
            // Update the map view viewpoint and the triangle graphic's position.
            triangleGraphic.geometry = frame.position
            viewpoint = Viewpoint(center: frame.position, scale: 100_000, rotation: 360 + frame.heading.value)
        }
    }
    
    /// A struct containing data for an animation.
    struct Animation {
        /// The timer for the animation used to loop through the animation frames.
        var timer: Timer?
        
        /// The speed of the animation used to set the timer's time interval.
        var speed: Int = 50
        
        /// A Boolean that indicates whether the animation is current playing.
        var isPlaying = false
        
        /// The current frame of the animation.
        var currentFrame: Frame {
            frames[currentFrameIndex]
        }
        
        /// The all frames of the animation.
        private(set) var frames: [Frame] = []
        
        /// The index of the current frame in the frames list.
        private var currentFrameIndex = 0
        
        /// Stops the animation by invalidating the timer.
        mutating func stop() {
            timer?.invalidate()
            isPlaying = false
        }
        
        /// Resets the animation to the beginning in an unplayed state.
        mutating func reset() {
            stop()
            currentFrameIndex = 0
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
        
        /// Loads the frames of a mission from a CSV file.
        /// - Parameter filename: The name the file containing the CSV data.
        mutating func loadFrames(for filename: String) {
            // Get the path of the file in the bundle using the filename name.
            guard let path = Bundle.main.path(forResource: filename, ofType: "csv") else { return }
            
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
    
    /// An enumeration of the different mission selections available in this sample.
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
    static var worldElevationService: Self {
        .init(string: "https://elevation3d.arcgis.com/arcgis/rest/services/WorldElevation3D/Terrain3D/ImageServer")!
    }
    
    /// A URL to the local Bristol 3D model files.
    static var bristol: Self {
        Bundle.main.url(forResource: "Bristol", withExtension: "dae", subdirectory: "Bristol")!
    }
}
