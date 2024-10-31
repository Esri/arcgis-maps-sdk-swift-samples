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

struct ShowViewshedFromPointOnMapView: View {
    /// The error shown in the error alert.
    @State private var error: Error?
    
    /// The point on the map where the user tapped.
    @State private var tapLocation: Point?
    
    /// The current geoprocessing status.
    @State private var geoprocessingInProgress = false
    
    /// The data model for the sample.
    @StateObject private var model = Model()
    
    var body: some View {
        MapView(map: model.map, graphicsOverlays: [model.inputGraphicsOverlay, model.resultGraphicsOverlay])
            .onSingleTapGesture { _, tapPoint in
                tapLocation = tapPoint
            }
        // Disables tap while geoprocessing is in progress.
            .allowsHitTesting(!geoprocessingInProgress)
            .task(id: tapLocation) {
                guard let tapLocation else { return }
                model.addInputGraphic(at: tapLocation)
                geoprocessingInProgress = true
                do {
                    try await model.calculateViewshed(at: tapLocation)
                    geoprocessingInProgress = false
                } catch {
                    self.error = error
                    // This is set because errorAlert hides cancellation errors,
                    // however when kicking off new job, we cancel any in progress
                    // jobs which leads to wrong behavior.
                    if !(error is CancellationError) {
                        geoprocessingInProgress = false
                    }
                }
            }
            .overlay(alignment: .center) {
                // Sets indication when geoprocessingInProgress is true.
                if geoprocessingInProgress {
                    ProgressView("Geoprocessing \n   in progress…")
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(.rect(cornerRadius: 10))
                        .shadow(radius: 50)
                }
            }
            .errorAlert(presentingError: $error)
    }
}

private extension ShowViewshedFromPointOnMapView {
    @MainActor
    class Model: ObservableObject {
        /// A map with topographic basemap.
        let map: Map = {
            let map = Map(basemapStyle: .arcGISTopographic)
            // Sets map's initial viewpoint to Vanoise National Park in France.
            map.initialViewpoint = Viewpoint(
                center: Point(latitude: 45.379, longitude: 6.849),
                scale: 144447
            )
            return map
        }()
        
        /// The processing task that references the online resource through the url.
        private let geoprocessingTask = GeoprocessingTask(url: .viewshedURL)
        
        /// Handles the execution of the geoprocessing task and gets the result.
        private var geoprocessingJob: GeoprocessingJob?
        
        /// The graphics overlay that displays the viewshed for the tapped location.
        let resultGraphicsOverlay: GraphicsOverlay = {
            let resultGraphicsOverlay = GraphicsOverlay()
            let fillColor = UIColor.orange.withAlphaComponent(0.4)
            let fillSymbol = SimpleFillSymbol(
                style: .solid,
                color: fillColor
            )
            let resultRenderer = SimpleRenderer(symbol: fillSymbol)
            resultGraphicsOverlay.renderer = resultRenderer
            return resultGraphicsOverlay
        }()
        
        /// The graphics overlay that shows where the user tapped on the screen.
        let inputGraphicsOverlay: GraphicsOverlay = {
            let inputGraphicsOverlay = GraphicsOverlay()
            // Red dot marker that is added to graphic overlay on map on the location where the user taps.
            let pointSymbol = SimpleMarkerSymbol(style: .circle, color: .red, size: 10)
            // Sets the renderer to draw the dot symbol on the graphics overlay.
            let renderer = SimpleRenderer(symbol: pointSymbol)
            inputGraphicsOverlay.renderer = renderer
            return inputGraphicsOverlay
        }()
        
        /// Removes previously tapped location from overlay and draws new dot on tap location.
        /// - Parameter point: Location to add a dot graphic on the map.
        func addInputGraphic(at point: Point) {
            inputGraphicsOverlay.removeAllGraphics()
            let graphic = Graphic(geometry: point)
            inputGraphicsOverlay.addGraphic(graphic)
        }
        
        /// Controls the initialization for the geoprocessing of the viewshed and calls the geoprocessing logic.
        /// - Parameter point: Location that the user tapped on the map.
        func calculateViewshed(at point: Point) async throws {
            // Clears previously viewshed drawing.
            resultGraphicsOverlay.removeAllGraphics()
            // If there is a geoprocessing job in progress it is cancelled.
            await geoprocessingJob?.cancel()
            guard let spatialReference = point.spatialReference else { return }
            // Creates a feature collection table based on the spatial reference for the tapped location
            // on the map.
            let featureCollectionTable = FeatureCollectionTable(
                fields: [],
                geometryType: Point.self,
                spatialReference: spatialReference
            )
            // Creates a feature for the point tapped.
            let feature = featureCollectionTable.makeFeature(geometry: point)
            // Asynchronously adds that feature to the table.
            try await featureCollectionTable.add(feature)
            try await performGeoprocessing(featureCollectionTable)
        }
        
        /// Contains the logic for the geoprocessing and passes the result on to another function to display.
        /// - Parameter featureCollectionTable: Holds the tapped location feature.
        private func performGeoprocessing(_ featureCollectionTable: FeatureCollectionTable) async throws {
            let params = GeoprocessingParameters(executionType: .synchronousExecute)
            // Sets the parameters spatial reference to the point tapped on the map.
            params.processSpatialReference = featureCollectionTable.spatialReference
            params.outputSpatialReference = featureCollectionTable.spatialReference
            // Creates a feature with the feature collection table which has the reference to the tapped location.
            let geoprocessingFeature = GeoprocessingFeatures(features: featureCollectionTable)
            // Sets the observation point to the tapped location.
            params.setInputValue(geoprocessingFeature, forKey: "Input_Observation_Point")
            // Creates geoprocessing job and kicks off process of getting viewshed for the point.
            let job = geoprocessingTask.makeJob(parameters: params)
            geoprocessingJob = job
            defer { geoprocessingJob = nil }
            job.start()
            // Gets the result of the geoprocessing job asynchronously.
            let output = try await job.output
            // If the feature set is returned from the geoprocessing, it iterates through each feature and adds it to the
            // graphic overlay to display to the user.
            if let resultFeatures = output.outputs["Viewshed_Result"] as? GeoprocessingFeatures,
               let featureSet = resultFeatures.features {
                resultGraphicsOverlay.addGraphics(featureSet.features().map {
                    Graphic(geometry: $0.geometry)
                })
            }
        }
    }
}

private extension URL {
    static let viewshedURL = URL(
        string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/Elevation/ESRI_Elevation_World/GPServer/Viewshed"
    )!
}

#Preview {
    ShowViewshedFromPointOnMapView()
}
