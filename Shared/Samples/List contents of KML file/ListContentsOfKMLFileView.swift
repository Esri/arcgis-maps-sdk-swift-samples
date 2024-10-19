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

struct ListContentsOfKMLFileView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    var body: some View {
        VStack(spacing: 0) {
            Text("Tap on a disclosure to reveal a node's children. Tap on a node to open it in a scene.")
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(8)
                .background(Color(.systemGroupedBackground))
            
            // Recursively displays the dataset's nodes in a list.
            List(model.kmlDataset?.rootNodes ?? [], id: \.name, children: \.children) { node in
                VStack(alignment: .leading) {
                    NavigationLink {
                        if let viewpoint = model.nodeViewpoints[node.name] {
                            SceneView(scene: model.scene, viewpoint: viewpoint)
                                .navigationTitle(node.name)
                        } else {
                            Text("This node has no extent to view.")
                                .navigationTitle(node.name)
                        }
                    } label: {
                        VStack(alignment: .leading) {
                            if !node.name.isEmpty {
                                Text(node.name)
                            }
                            Text(node.typeLabel)
                                .font(.footnote)
                        }
#if targetEnvironment(macCatalyst)
                        .padding(.leading)
#endif
                    }
                }
            }
        }
        .errorAlert(presentingError: $model.error)
    }
}

// MARK: Model

private extension ListContentsOfKMLFileView {
    /// The view model for the sample.
    @MainActor
    final class Model: ObservableObject {
        /// A dataset containing the KML data from a local file.
        @Published private(set) var kmlDataset: KMLDataset?
        
        /// The viewpoints for the nodes in the dataset.
        @Published private(set) var nodeViewpoints: [String: Viewpoint] = [:]
        
        /// The error shown in the error alert.
        @Published var error: Error?
        
        /// A scene for displaying the KML data.
        let scene: ArcGIS.Scene = {
            let scene = Scene(basemapStyle: .arcGISImagery)
            let elevationSource = ArcGISTiledElevationSource(url: .worldElevationService)
            scene.baseSurface.addElevationSource(elevationSource)
            return scene
        }()
        
        /// The task used for the asynchronous setup operations.
        private var setupTask: Task<Void, Error>?
        
        init() {
            setupTask = Task { [weak self] in
                guard let self else { return }
                
                do {
                    try await setUpKMLDataset()
                } catch {
                    self.error = error
                }
            }
        }
        
        deinit {
            setupTask?.cancel()
        }
        
        /// Sets up the KML dataset and adds it to the scene as layer.
        private func setUpKMLDataset() async throws {
            // Creates the dataset using a local ".kml" file in the bundle.
            let kmlDataset = KMLDataset(name: "esri_test_data", bundle: .main)!
            try await kmlDataset.load()
            self.kmlDataset = kmlDataset
            
            // Adds the dataset to the scene as a KML layer.
            let kmlLayer = KMLLayer(dataset: kmlDataset)
            scene.addOperationalLayer(kmlLayer)
            try await scene.load()
            
            try await setUpKMLNodes(kmlDataset.rootNodes)
        }
        
        /// Recursively creates viewpoints for KML nodes in a given list.
        /// - Parameter kmlNodes: The list of KML nodes to set up.
        private func setUpKMLNodes(_ kmlNodes: [KMLNode]) async throws {
            // Loads the surface so that the elevation can be queried when the viewpoint is made.
            try await scene.baseSurface.load()
            
            for node in kmlNodes {
                let viewpoint = try await Viewpoint(kmlNode: node, surface: scene.baseSurface)
                nodeViewpoints[node.name] = viewpoint
                
                // Ensures the node is visible since some are hidden by default.
                node.isVisible = true
                
                if let childNodes = node.children {
                    try await setUpKMLNodes(childNodes)
                }
            }
        }
    }
}

// MARK: Helper Extensions

private extension KMLNode {
    /// The child nodes of the node, if any.
    var children: [KMLNode]? {
        switch self {
        case let container as KMLContainer:
            container.childNodes
        case let networkLink as KMLNetworkLink:
            networkLink.childNodes
        default:
            nil
        }
    }
    
    /// A human-readable label of the type of the node.
    var typeLabel: String {
        switch self {
        case is KMLDocument: "Document"
        case is KMLFolder: "Folder"
        case is KMLContainer: "Container"
        case is KMLGroundOverlay: "Ground Overlay"
        case is KMLNetworkLink: "Network Link"
        case is KMLPhotoOverlay: "Photo Overlay"
        case is KMLPlacemark: "Placemark"
        case is KMLScreenOverlay: "Screen Overlay"
        case is KMLTour: "Tour"
        default: "Unknown"
        }
    }
}

private extension Viewpoint {
    /// Creates a viewpoint from a KML node.
    /// - Parameters:
    ///   - kmlNode: The KML node.
    ///   - surface: A surface for determining the elevation needed to offset the viewpoint.
    init?(kmlNode: KMLNode, surface: Surface) async throws {
        if let kmlViewpoint = kmlNode.viewpoint {
            try await self.init(kmlViewpoint: kmlViewpoint, surface: surface)
        } else if let extent = kmlNode.extent {
            // the node does not have a predefined viewpoint, so create a viewpoint based on its extent
            try await self.init(kmlNodeExtent: extent, surface: surface)
        } else {
            return nil
        }
    }
    
    /// Creates a viewpoint from a KML viewpoint.
    /// - Parameters:
    ///   - kmlViewpoint: The KML viewpoint.
    ///   - surface: A surface for determining the elevation needed to offset the viewpoint.
    private init(kmlViewpoint: KMLViewpoint, surface: Surface) async throws {
        switch kmlViewpoint.kind {
        case .lookAt:
            var lookAtPoint = kmlViewpoint.location
            if kmlViewpoint.altitudeMode != .absolute {
                // If the elevation is relative, account for the surface's elevation.
                let elevation = try await surface.elevation(at: kmlViewpoint.location)
                lookAtPoint = kmlViewpoint.location.withBuilder { $0.z += elevation }
            }
            
            let camera = Camera(
                lookingAt: lookAtPoint,
                distance: kmlViewpoint.range,
                heading: kmlViewpoint.heading,
                pitch: kmlViewpoint.pitch,
                roll: kmlViewpoint.roll
            )
            self.init(latitude: .nan, longitude: .nan, scale: .nan, camera: camera)
        case .camera:
            let camera = Camera(
                location: kmlViewpoint.location,
                heading: kmlViewpoint.heading,
                pitch: kmlViewpoint.pitch,
                roll: kmlViewpoint.roll
            )
            self.init(latitude: .nan, longitude: .nan, scale: .nan, camera: camera)
        @unknown default:
            fatalError("Unexpected KMLViewpoint.Kind: \(kmlViewpoint.kind)")
        }
    }
    
    /// Creates a viewpoint from the extent of a KML node.
    /// - Parameters:
    ///   - extent: The extent of a KML node.
    ///   - surface: A surface for determining the elevation needed to offset the viewpoint.
    private init?(kmlNodeExtent extent: Envelope, surface: Surface) async throws {
        // Ensures the extent isn't empty since some nodes don't include a geometry.
        guard !extent.isEmpty else { return nil }
        
        let extentCenter = extent.center
        let elevation = try await surface.elevation(at: extentCenter)
        
        if extent.extent.width == 0, extent.height == 0 {
            // If the extent is not empty, but the width and height are still zero,
            // default values (based on Google Earth) are used to create a camera.
            let elevatedCenter = extentCenter.withBuilder { $0.z += elevation }
            let camera = Camera(
                lookingAt: elevatedCenter,
                distance: 1000,
                heading: 0,
                pitch: 45,
                roll: 0
            )
            self.init(latitude: .nan, longitude: .nan, scale: .nan, camera: camera)
        } else {
            // Adds the elevation and a buffer to the extent.
            let bufferedExtent = extent.withBuilder { builder in
                builder.zMin += elevation
                builder.zMax += elevation
                builder.expand(by: 1.1)
            }
            self.init(boundingGeometry: bufferedExtent)
        }
    }
}

private extension URL {
    /// A web URL to the Terrain3D image server on ArcGIS REST.
    static var worldElevationService: URL {
        URL(string: "https://elevation3d.arcgis.com/arcgis/rest/services/WorldElevation3D/Terrain3D/ImageServer")!
    }
}
