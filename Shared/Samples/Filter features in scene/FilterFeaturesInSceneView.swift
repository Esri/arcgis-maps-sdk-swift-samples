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

struct FilterFeaturesInSceneView: View {
    /// The view model for this sample.
    @StateObject private var model = Model()
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    var body: some View {
        SceneView(scene: model.scene, graphicsOverlays: [model.graphicsOverlay])
            .task {
                do {
                    try await model.scene.load()
                } catch {
                    self.error = error
                }
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button(model.filterState.label) {
                        model.handleFilterState()
                    }
                }
            }
            .errorAlert(presentingError: $error)
    }
}

private extension FilterFeaturesInSceneView {
    /// The model used to store the geo model and other expensive objects
    /// used in this view.
    @MainActor
    class Model: ObservableObject {
        /// The scene for this sample.
        let scene: ArcGIS.Scene
        
        /// The open street map layer for the sample.
        private let osmBuildings = ArcGISSceneLayer(
            item: PortalItem(
                portal: .arcGISOnline(connection: .anonymous),
                id: .osmBuildings
            )
        )
        
        /// The San Francisco buildings scene layer for the sample.
        private let buildingsSceneLayer = ArcGISSceneLayer(
            url: URL(string: "https://tiles.arcgis.com/tiles/z2tnIkrLQ2BRzr6P/arcgis/rest/services/SanFrancisco_Bldgs/SceneServer")!
        )
        
        /// The graphics overlay for the scene view.
        let graphicsOverlay = GraphicsOverlay()
        
        /// A polygon that shows the extent of the detailed buildings scene layer.
        private let polygon: ArcGIS.Polygon = makeFilteringPolygon()
        
        /// A red extent boundary graphic that represents the full extent of the detailed buildings scene layer.
        private let sanFranciscoExtentGraphic: Graphic
        
        /// The filter state for the scene view.
        @Published private(set) var filterState: FilterState = .addBuildings
        
        init() {
            // Create basemap.
            let vectorTiledLayer = ArcGISVectorTiledLayer(
                item: PortalItem(
                    portal: .arcGISOnline(connection: .anonymous),
                    id: .osmTopographic
                )
            )
            scene = Scene(basemap: Basemap(baseLayers: [vectorTiledLayer, osmBuildings]))
            
            // Create scene topography.
            let elevationServiceURL = URL(string: "https://elevation3d.arcgis.com/arcgis/rest/services/WorldElevation3D/Terrain3D/ImageServer")!
            let elevationSource = ArcGISTiledElevationSource(url: elevationServiceURL)
            let surface = Surface()
            surface.addElevationSource(elevationSource)
            scene.baseSurface = surface
            
            // Set the initial viewpoint of the scene.
            scene.initialViewpoint = .sanFranciscoBuildings
            
            let simpleFillSymbol = SimpleFillSymbol(
                style: .solid,
                color: .clear,
                outline: SimpleLineSymbol(
                    style: .solid,
                    color: .red,
                    width: 5
                )
            )
            
            sanFranciscoExtentGraphic = Graphic(
                geometry: polygon,
                symbol: simpleFillSymbol
            )
        }
        
        /// Creates a polygon that represents the detailed buildings scene layer full extent.
        /// - Returns: A polygon.
        private static func makeFilteringPolygon() -> ArcGIS.Polygon {
            // The buildings scene layer fullExtent.
            let extent = Envelope(
                xRange: -122.514 ... -122.357,
                yRange: 37.705...37.831,
                zRange: -148.843...551.801,
                spatialReference: SpatialReference(wkid: .wgs84, verticalWKID: WKID(5773)!)
            )
            
            let builder = PolygonBuilder(spatialReference: extent.spatialReference)
            builder.add(Point(x: extent.xMin, y: extent.yMin))
            builder.add(Point(x: extent.xMax, y: extent.yMin))
            builder.add(Point(x: extent.xMax, y: extent.yMax))
            builder.add(Point(x: extent.xMin, y: extent.yMax))
            
            return builder.toGeometry()
        }
        
        /// Handles the filter state of the sample by either loading, filtering, or reseting the scene.
        func handleFilterState() {
            switch filterState {
            case .addBuildings:
                // Show the detailed buildings scene layer and extent graphic.
                addBuildings()
            case .filter:
                // Hide buildings within the detailed building extent so they don't clip.
                filterScene()
            case .reset:
                // Reset the scene to its original state.
                resetScene()
            }
            
            // Set the next filter state to be applied to the scene.
            filterState = filterState.next()
        }
        
        /// Loads the detailed buildings scene layer and adds an extent graphic.
        private func addBuildings() {
            scene.addOperationalLayer(buildingsSceneLayer)
            graphicsOverlay.addGraphic(sanFranciscoExtentGraphic)
        }
        
        /// Applies a polygon filter to the open street map buildings layer.
        private func filterScene() {
            if let polygonFilter = osmBuildings.polygonFilter {
                // After the scene is reset, the layer will have a polygon filter, but that filter
                // will not have polygons set.
                // Add the polygon back to the polygon filter.
                polygonFilter.addPolygon(polygon)
            } else {
                // Initially, the building layer does not have a polygon filter, set it.
                osmBuildings.polygonFilter = SceneLayerPolygonFilter(
                    polygons: [polygon],
                    spatialRelationship: .disjoint
                )
            }
        }
        
        /// Resets the scene filters and hides the detailed buildings and extent graphic.
        private func resetScene() {
            // Remove the detailed buildings layer from the scene.
            scene.removeAllOperationalLayers()
            // Clear OSM buildings polygon filter.
            osmBuildings.polygonFilter?.removeAllPolygons()
            // Remove red extent boundary graphic from graphics overlay.
            graphicsOverlay.removeAllGraphics()
        }
    }
    
    /// The different states for filtering features in a scene.
    enum FilterState: Equatable {
        case addBuildings, filter, reset
        
        /// A human-readable label for the filter state.
        var label: String {
            switch self {
            case .addBuildings: return "Add Buildings"
            case .filter: return "Filter"
            case .reset: return "Reset"
            }
        }
        
        /// The next filter state to apply to a scene.
        func next() -> Self {
            switch self {
            case .addBuildings:
                return .filter
            case .filter:
                return .reset
            case .reset:
                return .addBuildings
            }
        }
    }
}

private extension PortalItem.ID {
    /// The ID used in the "OpenStreetMap 3D Buildings" portal item.
    static var osmBuildings: Self { Self("ca0470dbbddb4db28bad74ed39949e25")! }
    /// The ID used in the "OpenStreetMap Topographic (for 3D)" portal item.
    static var osmTopographic: Self { Self("1e7d1784d1ef4b79ba6764d0bd6c3150")! }
}

private extension Viewpoint {
    /// The initial viewpoint to be displayed when the sample is first opened.
    static let sanFranciscoBuildings = Viewpoint(
        latitude: .nan,
        longitude: .nan,
        scale: .nan,
        camera: Camera(
            location: Point(
                x: -122.421,
                y: 37.7041,
                z: 207
            ),
            heading: 60,
            pitch: 70,
            roll: 0
        )
    )
}

#Preview {
    NavigationView {
        FilterFeaturesInSceneView()
    }
}
