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
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    /// A Boolean value that indicates whether to disable the tour buttons.
    private var tourDisabled: Bool {
        tourStatus == .notInitialized || tourStatus == .initializing
    }
    
    var body: some View {
        // Create a scene view with a scene and a viewpoint.
        SceneView(scene: scene, viewpoint: viewpoint)
            .task {
                do {
                    // Add KML layer to the scene.
                    let dataset = KMLDataset(url: .esriTour)
                    try await dataset.load()
                    let layer = KMLLayer(dataset: dataset)
                    scene.addOperationalLayer(layer)
                    
                    // Set the tour controller with first tour in the dataset.
                    tourController.tour = dataset.tours.first
                    
                    // Listen for tour status updates.
                    if let tour = tourController.tour {
                        for await status in tour.$status {
                            tourStatus = status
                        }
                    }
                } catch {
                    self.error = error
                }
            }
            .onDisappear {
                tourController.pause()
            }
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button {
                        tourController.reset()
                        viewpoint = scene.initialViewpoint
                    } label: {
                        Image(systemName: "gobackward")
                    }
                    .disabled(tourDisabled || tourStatus == .initialized)
                    Spacer()
                    Button {
                        tourStatus == .playing ? tourController.pause() : tourController.play()
                    } label: {
                        Image(systemName: tourStatus == .playing ? "pause.fill" : "play.fill")
                    }
                    .disabled(tourDisabled)
                    Spacer()
                }
            }
            .overlay(alignment: .top) {
                Text("Tour status: \(String(describing: tourStatus).titleCased)")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(8)
                    .background(.thinMaterial, ignoresSafeAreaEdges: .horizontal)
            }
            .overlay(alignment: .center) {
                if tourDisabled {
                    ProgressView()
                        .padding()
                        .background(.ultraThickMaterial)
                        .cornerRadius(10)
                        .shadow(radius: 50)
                }
            }
            .errorAlert(presentingError: $error)
    }
}

private extension KMLDataset {
    /// All the tours in the dataset.
    var tours: [KMLTour] { rootNodes.tours }
}

private extension KMLContainer {
    /// All the tours in the container.
    var tours: [KMLTour] { childNodes.tours }
}

private extension Sequence where Element == KMLNode {
    /// All the tours in the node sequence.
    var tours: [KMLTour] {
        reduce(into: []) { tours, node in
            switch node {
            case let tour as KMLTour:
                tours.append(tour)
            case let container as KMLContainer:
                tours.append(contentsOf: container.tours)
            default:
                break
            }
        }
    }
}

private extension String {
    // A copy of a camel cased string broken into words with capital letters.
    var titleCased: String {
        self
            .replacingOccurrences(of: "([A-Z])", with: " $1", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .capitalized
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

#Preview {
    NavigationView {
        PlayKMLTourView()
    }
}
