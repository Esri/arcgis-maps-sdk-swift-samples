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
    /// The result of the loading the view model for this sample.
    @State private var modelResult: Result<Model, any Error>?
    
    var body: some View {
        switch modelResult {
        case .success(let model):
            SceneView(scene: model.scene, graphicsOverlays: [model.graphicsOverlay])
                .toolbar {
                    ToolbarItem(placement: .bottomBar) {
                        Button(model.filterState.label) {
                            model.handleFilterState()
                        }
                    }
                }
        case .failure(let error):
            ContentUnavailableView {
                Label("Error Setting Up Sample", systemImage: "exclamationmark.triangle")
            } description: {
                Text(String(reflecting: error))
            } actions: {
                Button("Retry") { modelResult = nil }
            }
        case nil:
            ProgressView("Loading model")
                .task {
                    modelResult = await Result(awaiting: Model.init)
                }
        }
    }
}

private extension FilterFeaturesInSceneView {
    /// The model used to store the geo model and other expensive objects
    /// used in this view.
    @MainActor
    @Observable
    final class Model {
        /// The scene for this sample.
        let scene: ArcGIS.Scene = {
            let scene = Scene()
            
            // Adds the World Elevation 3D elevation source to the scene's base surface.
            let elevationSource = ArcGISTiledElevationSource(url: .worldElevationService)
            scene.baseSurface.addElevationSource(elevationSource)
            
            // Sets the initial viewpoint for the scene.
            scene.initialViewpoint = .sanFranciscoBuildings
            
            return scene
        }()
        
        /// The "Buildings" ArcGIS scene layer from the scene's basemap.
        private let buildingsLayer: ArcGISSceneLayer
        
        /// An ArcGIS scene layer containing detailed buildings in San Francisco, CA, USA.
        private let detailedBuildingsLayer = ArcGISSceneLayer(url: .sanFranciscoBuildings)
        
        /// The graphics overlay for the scene view.
        let graphicsOverlay = GraphicsOverlay()
        
        /// A polygon filter for filtering the features in the `buildingsLayer`.
        private let polygonFilter: SceneLayerPolygonFilter
        
        /// A red extent boundary graphic that represents the full extent of the detailed buildings scene layer.
        private let sanFranciscoExtentGraphic: Graphic = {
            // Creates a graphic from a red outline symbol.
            let redLineSymbol = SimpleLineSymbol(color: .red, width: 5)
            let redOutlineFillSymbol = SimpleFillSymbol(color: .clear, outline: redLineSymbol)
            let graphic = Graphic(symbol: redOutlineFillSymbol)
            
            // Initially hides the graphic, since the filter has not been applied yet.
            graphic.isVisible = false
            
            return graphic
        }()
        
        /// The filter state for the scene view.
        private(set) var filterState: FilterState = .filter
        
        init() async throws {
            // Creates the "Navigation" 3D basemap and sets it on the scene.
            let basemap = Basemap(url: .navigation3DBasemap)!
            scene.basemap = basemap
            
            // Gets the "Buildings" base layer from the basemap.
            try await basemap.load()
            let buildingsBaseLayer = basemap.baseLayers.first(where: { $0.name == "Buildings" })
            guard let buildingsLayer = buildingsBaseLayer as? ArcGISSceneLayer else {
                throw SetupError.missingBuildingsLayer
            }
            self.buildingsLayer = buildingsLayer
            
            // Creates a polygon from the detailedBuildingsLayer's extent.
            try await detailedBuildingsLayer.load()
            guard let extent = detailedBuildingsLayer.fullExtent else {
                throw SetupError.missingDetailedBuildingsLayerExtent
            }
            let polygon = Polygon(points: [
                Point(x: extent.xMin, y: extent.yMin),
                Point(x: extent.xMax, y: extent.yMin),
                Point(x: extent.xMax, y: extent.yMax),
                Point(x: extent.xMin, y: extent.yMax)
            ])
            
            // Adds the polygon to the graphic and adds the graphic to the overlay.
            sanFranciscoExtentGraphic.geometry = polygon
            graphicsOverlay.addGraphic(sanFranciscoExtentGraphic)
            
            // Creates a disjoint scene layer polygon filter using the polygon.
            polygonFilter = SceneLayerPolygonFilter(
                polygons: [polygon],
                spatialRelationship: .disjoint
            )
            
            // Adds the detailed buildings layer to the scene.
            // The layer is also initially hidden to that it doesn't
            // clip into the `buildingsLayer` while it is unfiltered.
            detailedBuildingsLayer.isVisible = false
            scene.addOperationalLayer(detailedBuildingsLayer)
        }
        
        /// Handles the filter state of the sample.
        func handleFilterState() {
            switch filterState {
            case .filter:
                // Applies the polygon filter to the buildings layer and shows the extent graphic.
                buildingsLayer.polygonFilter = polygonFilter
                sanFranciscoExtentGraphic.isVisible = true
            case .showDetailedBuildings:
                // Shows the detailed buildings scene layer.
                detailedBuildingsLayer.isVisible = true
            case .reset:
                // Reset the scene to its original state.
                resetScene()
            }
            
            // Set the next filter state to be applied to the scene.
            filterState = filterState.next()
        }
        
        /// Resets the scene filters and hides the detailed buildings and extent graphic.
        private func resetScene() {
            // Hides the detailed buildings layer.
            detailedBuildingsLayer.isVisible = false
            // Removes the polygon filter from the building layer.
            buildingsLayer.polygonFilter = nil
            // Hides the red extent boundary graphic.
            sanFranciscoExtentGraphic.isVisible = false
        }
    }
    
    /// The different states for filtering features in a scene.
    enum FilterState {
        case filter, showDetailedBuildings, reset
        
        /// A human-readable label for the filter state.
        var label: String {
            switch self {
            case .filter: "Filter"
            case .showDetailedBuildings: "Show Detailed Buildings"
            case .reset: "Reset"
            }
        }
        
        /// The next filter state to apply to a scene.
        func next() -> Self {
            switch self {
            case .filter:
                return .showDetailedBuildings
            case .showDetailedBuildings:
                return .reset
            case .reset:
                return .filter
            }
        }
    }
    
    /// An error that can occur during the sample's setup.
    enum SetupError: Error {
        case missingBuildingsLayer
        case missingDetailedBuildingsLayerExtent
    }
}

private extension URL {
    /// The URL to the "Navigation" 3D basemap on ArcGIS Online.
    static var navigation3DBasemap: URL {
        URL(string: "https://www.arcgis.com/home/item.html?id=00a5f468dda941d7bf0b51c144aae3f0")!
    }
    
    /// The URL to the San Francisco Buildings scene server on ArcGIS REST.
    static var sanFranciscoBuildings: URL {
        URL(string: "https://tiles.arcgis.com/tiles/z2tnIkrLQ2BRzr6P/arcgis/rest/services/SanFrancisco_Bldgs/SceneServer")!
    }
    
    /// The URL to the World Elevation 3D image server on ArcGIS REST.
    static var worldElevationService: URL {
        URL(string: "https://elevation3d.arcgis.com/arcgis/rest/services/WorldElevation3D/Terrain3D/ImageServer")!
    }
}

private extension Viewpoint {
    /// The initial viewpoint to be displayed when the sample is first opened.
    static let sanFranciscoBuildings = Viewpoint(
        latitude: .nan,
        longitude: .nan,
        scale: .nan,
        camera: Camera(
            latitude: 37.702425,
            longitude: -122.421008,
            altitude: 207,
            heading: 60,
            pitch: 70,
            roll: 0
        )
    )
}

#Preview {
    NavigationStack {
        FilterFeaturesInSceneView()
    }
}
