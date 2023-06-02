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

struct AnimateImagesWithImageOverlayView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// A Boolean indicating wHether the speed options sheet is showing
    @State private var isShowingSpeedOptions = false
    
    var body: some View {
        // Create a scene view to display the scene.
        SceneView(scene: model.scene, imageOverlays: [model.imageOverlay])
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    VStack {
                        HStack {
                            Button(model.startStopButtonText) {
                                model.startStopButtonText = model.startStopButtonText == "Start" ? "Stop" : "Start"
                                model.displayLink.isPaused.toggle()
                            }
                            Spacer()
                            Button("Speed") {
                                model.displayLink.preferredFramesPerSecond = 30
                            }
                        }
                        HStack {
                            Slider(value: $model.opacity, in: 0.0...1.0, step: 0.01) { _ in
                                model.imageOverlay.opacity = model.opacity
                            }
                            Text(model.percentageFormatter.string(from: model.opacity as NSNumber)!)
                        }
                    }
                }
            }
    }
}

private extension AnimateImagesWithImageOverlayView {
    /// The view model for the sample.
    class Model: ObservableObject {
        /// A scene
        var scene: ArcGIS.Scene = {
            // Creates a scene and sets an initial viewpoint.
            let scene = Scene(basemapStyle: .arcGISDarkGrayBase)
            let point = Point(x: -116.621, y: 24.7773, z: 856977.0, spatialReference: .wgs84)
            let camera = Camera(location: point, heading: 353.994, pitch: 48.5495, roll: 0)
            scene.initialViewpoint = Viewpoint(boundingGeometry: point, camera: camera)
            
            // Add base surface.
            let elevationSource = ArcGISTiledElevationSource(url: .elevationService)
            let surface = Surface()
            surface.addElevationSource(elevationSource)
            scene.baseSurface = surface
            
            return scene
        }()
        
        /// The image overlay to show image frames.
        lazy var imageOverlay: ImageOverlay = {
            let imageOverlay = ImageOverlay()
            imageOverlay.opacity = opacity
            return imageOverlay
        }()
        
        /// A timer to synchronize image overlay animation to the refresh rate
        /// of the display.
        var displayLink: CADisplayLink!
        
        /// Set the image frame to the next one.
        @objc
        func setImageFrame() {
            let frame = ImageFrame(image: imagesIterator.next()!, extent: pacificSouthwestEnvelope)
            imageOverlay.imageFrame = frame
        }
        
        /// An iterator to hold and loop through the overlay images.
        private lazy var imagesIterator: CircularIterator<UIImage> = {
            // Get the URLs to images added to the project's folder reference.
            let imageURLs = Bundle.main.urls(forResourcesWithExtension: "png", subdirectory: "PacificSouthWest2") ?? []
            print(imageURLs)
            let images = imageURLs
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
                .map { UIImage(contentsOfFile: $0.path)! }
            return CircularIterator(elements: images)
        }()
        
        /// An envelope of the pacific southwest sector for displaying the image frame.
        let pacificSouthwestEnvelope = Envelope(
            center: Point(latitude: 35.131016955536694, longitude: -120.0724273439448),
            width: 15.09589635986124,
            height: -14.3770441522488
        )
        
        /// A formatter to format percentage strings.
        let percentageFormatter: NumberFormatter = {
            let formatter = NumberFormatter()
            formatter.numberStyle = .percent
            formatter.multiplier = 100
            return formatter
        }()
        
        /// The text for the the start stop button.
        @Published var startStopButtonText = "Start"
        
        /// The opacity of the image overlay.
        @Published var opacity: Float = 1.0
        
        /// The frame rate speed of the image overlay
        @Published var fpsSpeed = 30
        
        init() {
            // Create new display link.
            let newDisplayLink = CADisplayLink(target: self, selector: #selector(setImageFrame))
            // Inherit the frame rate from existing display link, or set to default 60 fps.
            newDisplayLink.preferredFramesPerSecond = displayLink?.preferredFramesPerSecond ?? 60
            newDisplayLink.isPaused = true
            // Add to main thread common mode run loop, so it is not effected by UI events.
            newDisplayLink.add(to: .main, forMode: .common)
            displayLink = newDisplayLink
        }
    }
    
    /// A generic circular iterator.
    private struct CircularIterator<Element>: IteratorProtocol {
        let elements: [Element]
        private var elementIterator: Array<Element>.Iterator
        
        init(elements: [Element]) {
            self.elements = elements
            elementIterator = elements.makeIterator()
        }
        
        mutating func next() -> Element? {
            if let next = elementIterator.next() {
                return next
            } else {
                elementIterator = elements.makeIterator()
                return elementIterator.next()
            }
        }
    }
}

private extension URL {
    /// An elevation service from Terrain3D REST service.
    static var elevationService: URL {
        URL(string: "https://elevation3d.arcgis.com/arcgis/rest/services/WorldElevation3D/Terrain3D/ImageServer")!
    }
    
    /// Los Angeles Trailheads geodatabase.
    static var laTrails: URL { Bundle.main.url(forResource: "LA_Trails", withExtension: "geodatabase")! }
}
