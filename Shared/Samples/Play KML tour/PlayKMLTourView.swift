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

struct PlayKMLTourView: View {
    /// A scene with an imagery basemap and a world elevation service.
    @State private var scene: ArcGIS.Scene = {
        let scene = Scene(basemapStyle: .arcGISImagery)
        scene.initialViewpoint = Viewpoint(latitude: .nan, longitude: .nan, scale: 114_145_911)
        
        // Set the scene's base surface with an elevation source.
        let surface = Surface()
        let elevationSource = ArcGISTiledElevationSource(url: .worldElevationService)
        surface.addElevationSource(elevationSource)
        scene.baseSurface = surface
        return scene
    }()
    
    /// The current viewpoint of the scene view used when reseting the tour.
    @State private var viewpoint: Viewpoint?
    
    /// The tour controller used to control the KML tour.
    @State private var tourController = KMLTourController()
    
    /// The current status of the KML tour.
    @State private var tourStatus: KMLTour.Status = .notInitialized
    
    /// A Boolean that indicates whether to show an error alert.
    @State private var isShowingErrorAlert = false
    
    /// The error shown in the error alert.
    @State private var error: Error? {
        didSet { isShowingErrorAlert = error != nil }
    }
    
    /// A Boolean value that indicates whether the KML tour is not ready to be played.
    var tourIsNotReady: Bool {
        tourStatus == .notInitialized || tourStatus == .initializing
    }
    
    var body: some View {
        // Create a scene view with a scene and a viewpoint.
        SceneView(scene: scene, viewpoint: viewpoint)
            .onViewpointChanged(kind: .centerAndScale) { viewpoint = $0 }
            .task {
                do {
                    // Add KML layer to the scene.
                    let dataset = KMLDataset(url: .esriTour)
                    try await dataset.load()
                    let layer = KMLLayer(dataset: dataset)
                    scene.addOperationalLayer(layer)
                    
                    // Set the tour controller with first tour in the dataset.
                    if let tour = firstKMLTour(in: dataset) {
                        tourController.tour = tour
                        
                        // Listen for tour status updates.
                        for await status in tourController.tour!.$status {
                            tourStatus = status
                        }
                    }
                } catch {
                    self.error = error
                }
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    ZStack {
                        HStack {
                            Button {
                                tourController.reset()
                                viewpoint = scene.initialViewpoint
                            } label: {
                                Image(systemName: "gobackward")
                            }
                            .disabled(tourIsNotReady || tourStatus == .initialized)
                            Spacer()
                        }
                        
                        Button {
                            tourStatus == .playing ? tourController.pause() : tourController.play()
                        } label: {
                            Image(systemName: tourStatus == .playing ? "pause.fill" : "play.fill")
                        }
                        .disabled(tourIsNotReady)
                    }
                }
            }
            .alert(isPresented: $isShowingErrorAlert, presentingError: error)
    }
}

private extension PlayKMLTourView {
    /// Finds the first KML tour in a KML dataset.
    /// - Parameter dataset: The KML dataset to search through.
    /// - Returns: The first `KMLTour` object in the dataset if any.
    private func firstKMLTour(in dataset: KMLDataset) -> KMLTour? {
        var nodes = dataset.rootNodes
        var i = 0
        
        // Loop through the nodes until a tour is found.
        while i < nodes.count {
            if nodes[i] is KMLTour {
                return nodes[i] as? KMLTour
            }
            
            // If the current node is a container, add all of its children to be looped through.
            if nodes[i] is KMLContainer {
                nodes.append(contentsOf: (nodes[i] as! KMLContainer).childNodes)
            }
            i += 1
        }
        return nil
    }
}

private extension URL {
    /// A URL to world elevation service from Terrain3D ArcGIS REST service.
    static var worldElevationService: URL {
        URL(string: "https://elevation3d.arcgis.com/arcgis/rest/services/WorldElevation3D/Terrain3D/ImageServer")!
    }
    
    /// A URL to a KMZ file of an Esri Tour on ArcGIS Online.
    static var esriTour: URL {
        URL(string: "https://www.arcgis.com/sharing/rest/content/items/f10b1d37fdd645c9bc9b189fb546307c/data")!
    }
}
