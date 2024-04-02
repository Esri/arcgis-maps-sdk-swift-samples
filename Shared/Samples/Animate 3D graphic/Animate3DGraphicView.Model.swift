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
    @MainActor
    class Model: ObservableObject {
        // MARK: Scene
        
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
        
        /// The camera controller set to follow the plane model graphic.
        lazy var cameraController: OrbitGeoElementCameraController = {
            // Create a camera controller with the plane graphic and the default distance to keep from it.
            let cameraController = OrbitGeoElementCameraController(target: planeGraphic, distance: 1000)
            
            // Set camera to align its heading with the model graphic by default.
            cameraController.autoHeadingIsEnabled = true
            
            // Keep the camera still while the model graphic pitches or rolls by default.
            cameraController.autoPitchIsEnabled = false
            cameraController.autoRollIsEnabled = false
            
            // Set the min and max distance values between the model graphic and the camera.
            cameraController.minCameraDistance = CameraProperty.distance.range.lowerBound
            cameraController.maxCameraDistance = CameraProperty.distance.range.upperBound
            
            return cameraController
        }()
        
        /// The scene view graphics overlay containing the plane model graphic.
        private(set) lazy var sceneGraphicsOverlay: GraphicsOverlay = {
            // Create a graphics overlay and add the plane graphic.
            let graphicsOverlay = GraphicsOverlay(graphics: [planeGraphic])
            graphicsOverlay.sceneProperties.surfacePlacement = .absolute
            
            // Create a renderer and set its expressions.
            let renderer = SimpleRenderer()
            renderer.sceneProperties.headingExpression = "[HEADING]"
            renderer.sceneProperties.pitchExpression = "[PITCH]"
            renderer.sceneProperties.rollExpression = "[ROLL]"
            graphicsOverlay.renderer = renderer
            
            return graphicsOverlay
        }()
        
        /// The plane model scene symbol graphic for the scene.
        private let planeGraphic: Graphic = {
            // Create the model symbol for the plane using a URL.
            let planeModelSymbol = ModelSceneSymbol(url: .bristol, scale: 20)
            planeModelSymbol.anchorPosition = .center
            
            // Create graphic of the symbol.
            return Graphic(symbol: planeModelSymbol)
        }()
        
        // MARK: Map
        
        /// A map with a streets basemap used to display the location of the plane in 2D.
        let map = Map(basemapStyle: .arcGISStreets)
        
        /// The map view graphics overlay containing the map graphics.
        private(set) lazy var mapGraphicsOverlay: GraphicsOverlay = {
            // Create a graphics overlay with the route and triangle graphics.
            let graphicsOverlay = GraphicsOverlay(graphics: [routeGraphic, triangleGraphic])
            
            // Create a render and set the rotation expression.
            let renderer = SimpleRenderer()
            renderer.rotationExpression = "[ANGLE]"
            graphicsOverlay.renderer = renderer
            
            return graphicsOverlay
        }()
        
        /// The route line graphic used to represent the plane's route on the map.
        private let routeGraphic: Graphic = {
            let lineSymbol = SimpleLineSymbol(style: .solid, color: .blue, width: 1)
            return Graphic(symbol: lineSymbol)
        }()
        
        /// The triangle graphic used to represent the plane on the map.
        private let triangleGraphic: Graphic = {
            let triangleSymbol = SimpleMarkerSymbol(style: .triangle, color: .red, size: 10)
            return Graphic(symbol: triangleSymbol)
        }()
        
        /// The current viewpoint of the map view used to update it as the plane moves.
        private(set) var viewpoint: Viewpoint?
        
        /// The animation for the sample.
        @Published var animation = Animation()
        
        /// The current mission selection.
        @Published var currentMission: Mission = .grandCanyon {
            didSet {
                if oldValue != currentMission {
                    updateMission()
                }
            }
        }
        
        /// The text of the camera controller property values used for the camera settings.
        @Published private(set) var cameraPropertyTexts: [CameraProperty: String] = [:]
        
        init() {
            // Set up the mission, graphics, and animation.
            updateMission()
            
            let displayLink = CADisplayLink(target: self, selector: #selector(updatePositions))
            animation.setup(displayLink: displayLink)
        }
        
        deinit {
            Task { await animation.displayLink?.invalidate() }
        }
        
        // MARK: Methods
        
        /// Monitors the camera controller's properties to update the associated text when they change.
        func monitorCameraController() async {
            // The camera controller properties to monitor.
            let properties: [CameraProperty: AsyncStream<Double>] = [
                .distance: cameraController.$cameraDistance,
                .heading: cameraController.$cameraHeadingOffset,
                .pitch: cameraController.$cameraPitchOffset
            ]
            
            // Create a task for each property.
            await withTaskGroup(of: Void.self) { group in
                for (name, property) in properties {
                    group.addTask {
                        for await newValue in property {
                            await self.updateCameraPropertyText(for: name, using: newValue)
                        }
                    }
                }
            }
        }
        
        /// Updates the text associated with a given camera controller property.
        /// - Parameters:
        ///   - property: The camera controller property associated with the text to update.
        ///   - value: The property value used to create the text.
        private func updateCameraPropertyText(for property: CameraProperty, using value: Double) {
            let postfix = property == .distance ? " m" : "°"
            cameraPropertyTexts[property] = "\(value.formatted(.rounded))\(postfix)"
        }
        
        /// Switches to a new mission by updating the animation and graphics.
        private func updateMission() {
            // Reset the animation to the beginning.
            animation.reset()
            
            // Load the frames of the new mission.
            animation.loadFrames(for: currentMission.label.replacingOccurrences(of: " ", with: ""))
            
            // Create a polyline for the route using the position of each frame.
            let points = animation.frames.map { $0.position }
            routeGraphic.geometry = Polyline(points: points)
            
            // Set positions to the starting frame of the mission.
            updatePositions()
        }
        
        /// Updates the positions of the graphics and the viewpoint using the current frame.
        @objc
        private func updatePositions() {
            // Get the current frame of the animation.
            let frame = animation.currentFrame
            
            // Update the position and attributes of the plane model graphic.
            planeGraphic.geometry = frame.position
            planeGraphic.setAttributeValue(frame.heading.value, forKey: "HEADING")
            planeGraphic.setAttributeValue(frame.pitch.value, forKey: "PITCH")
            planeGraphic.setAttributeValue(frame.roll.value, forKey: "ROLL")
            
            // Update the viewpoint of the map view and the position of the triangle graphic.
            triangleGraphic.geometry = frame.position
            viewpoint = Viewpoint(center: frame.position, scale: 100_000, rotation: 360 + frame.heading.value)
            
            // Move to the next frame in the animation.
            if animation.isPlaying {
                animation.nextFrame()
            }
        }
    }
    
    /// A struct containing data for an animation.
    struct Animation {
        /// The timer used to loop through the animation frames.
        private(set) var displayLink: CADisplayLink?
        
        /// The speed of the animation.
        var speed = AnimationSpeed.medium
        
        /// A Boolean value indicating whether the animation is currently playing.
        var isPlaying = false {
            didSet {
                displayLink?.isPaused = !isPlaying
            }
        }
        
        /// The current frame of the animation.
        var currentFrame: Frame {
            frames[currentFrameIndex]
        }
        
        /// The current progress of the mission.
        var progress: Double {
            Double(currentFrameIndex) / Double(framesCount)
        }
        
        /// All the frames of the animation.
        private(set) var frames: [Frame] = [] {
            didSet {
                framesCount = frames.count
            }
        }
        
        /// The count of the frames.
        private var framesCount = 0
        
        /// The index of the current frame in the frames list.
        private var currentFrameIndex = 0
        
        /// Sets up the animation using a given display link.
        /// - Parameter displayLink: The display link used to run the animation.
        mutating func setup(displayLink: CADisplayLink) {
            // Add the display link to main thread common mode run loop,
            // so it is not effected by UI events.
            displayLink.add(to: .main, forMode: .common)
            displayLink.preferredFramesPerSecond = 60
            self.displayLink = displayLink
        }
        
        /// Resets the animation to the beginning.
        mutating func reset() {
            isPlaying = false
            currentFrameIndex = 0
        }
        
        /// Increments the animation to the next frame based on the speed.
        mutating func nextFrame() {
            // Increment the frame index using the current speed.
            let nextFrameIndex = currentFrameIndex + speed.rawValue
            if frames.indices.contains(nextFrameIndex) {
                currentFrameIndex = nextFrameIndex
            } else {
                // Reset the animation when it has reached the end.
                reset()
            }
        }
        
        /// Loads the frames of a mission from a CSV file.
        /// - Parameter filename: The name of the file containing the CSV data.
        mutating func loadFrames(for filename: String) {
            // Get the path of the file from the bundle using the filename name.
            guard let path = Bundle.main.path(forResource: filename, ofType: "csv") else { return }
            
            // Get the content of the file using the path.
            guard let content = try? String(contentsOfFile: path) else { return }
            
            // Split the content by line into an array.
            let lines = content.split(whereSeparator: \.isNewline)
            
            // Create a frame for each line.
            frames = lines.map { line in
                // Spilt the line data into an array.
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
    
    /// An enumeration representing the different async properties of the camera controller.
    enum CameraProperty: CaseIterable {
        case distance, heading, pitch
        
        /// A human-readable label of the property.
        var label: String {
            switch self {
            case .distance: return "Camera Distance"
            case .heading: return "Heading Offset"
            case .pitch: return "Pitch Offset"
            }
        }
        
        /// The range of values associated with the property.
        var range: ClosedRange<Double> {
            switch self {
            case .distance: return 500...8000
            case .heading: return -180...180
            case .pitch: return 0...180
            }
        }
    }
    
    /// An enumeration representing the speed of the animation.
    enum AnimationSpeed: Int, CaseIterable {
        case slow = 1
        case medium = 2
        case fast = 4
    }
}

private extension FormatStyle where Self == FloatingPointFormatStyle<Double> {
    /// The format style for rounding up decimals.
    static var rounded: Self {
        .number.rounded(rule: .up, increment: 1)
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
