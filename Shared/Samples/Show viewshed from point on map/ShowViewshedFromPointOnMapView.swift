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
    
    /// The point on the screen where the user tapped.
    @State private var tapScreenPoint: Point?
    
    /// The current geoprocessing status.
    @State private var geoprocessingInProgress = false
    
    /// The data model for the sample.
    @StateObject private var model = Model()
    
    var body: some View {
        MapView(map: model.map, graphicsOverlays: [model.inputGraphicsOverlay, model.resultGraphicsOverlay])
            .onSingleTapGesture { _, tapPoint in
                tapScreenPoint = tapPoint
            }
            .overlay(alignment: .center) {
                // Sets indication when geoprocessingInProgress is true.
                if geoprocessingInProgress {
                    ProgressView("Geoprocessing in progress…")
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                        .shadow(radius: 50)
                }
            }
            .task(id: tapScreenPoint) {
                guard let tapScreenPoint else { return }
                // Sets current geoprocessingInProgress to
                // false after geoprocessing is complete.
                defer { geoprocessingInProgress = false }
                model.addGraphic(at: tapScreenPoint)
                geoprocessingInProgress = true
                await calculateViewshed(at: tapScreenPoint)
            }
            .errorAlert(presentingError: $error)
    }
    
    /// Controls the initialization for the geoprocessing of the viewshed and calls the geoprocessing logic.
    /// - Parameter point: Location that the user tapped on the map.
    private func calculateViewshed(at point: Point) async {
        // Clears previously viewshed drawing.
        model.resultGraphicsOverlay.removeAllGraphics()
        // If there is a geoprocessing job in progress it is cancelled.
        await model.geoprocessingJob?.cancel()
        guard let spatialReference = point.spatialReference else { return }
        // Creates a feature collection table based on the spatial reference for the tapped location
        // on the map.
        let featureCollectionTable = FeatureCollectionTable(
            fields: [Field](),
            geometryType: Point.self,
            spatialReference: spatialReference
        )
        do {
            // Creates a feature for the point tapped.
            let feature = featureCollectionTable.makeFeature(geometry: point)
            // Asynchronously adds that feature to the table.
            try await featureCollectionTable.add(feature)
            await performGeoprocessing(featureCollectionTable)
        } catch {
            self.error = error
        }
    }
    
    /// Contains the logic for the geoprocessing and passes the result on to another function to display.
    /// - Parameter featureCollectionTable: Holds the tapped location feature
    private func performGeoprocessing(_ featureCollectionTable: FeatureCollectionTable) async {
        let params = GeoprocessingParameters(executionType: .synchronousExecute)
        // Sets the parameters spatial reference to the point tapped on the map.
        params.processSpatialReference = featureCollectionTable.spatialReference
        params.outputSpatialReference = featureCollectionTable.spatialReference
        // Create a feature with the feature collection table which has the reference to the tapped location.
        let geoprocessingFeature = GeoprocessingFeatures(features: featureCollectionTable)
        // Sets the observation point to the tapped location.
        params.setInputValue(geoprocessingFeature, forKey: "Input_Observation_Point")
        // Creates geoprocessing job and kicks off process of getting viewshed for the point.
        model.geoprocessingJob = model.geoprocessingTask.makeJob(parameters: params)
        model.geoprocessingJob?.start()
        // Get the result of the geoprocessing job asynchronously.
        let result = await model.geoprocessingJob?.result
        switch result {
        case .success(let output):
            if let resultFeatures = output.outputs["Viewshed_Result"] as? GeoprocessingFeatures {
                processFeatures(resultFeatures: resultFeatures)
            }
        case .failure(let error):
            // Sets error to be displayed.
            self.error = error
        case .none:
            // This case should never execute.
            break
        }
    }
    
    /// If the feature set is returned from the geoprocessing, it iterates through each feature and adds it to the
    /// graphic overlay to display to the user.
    /// - Parameter resultFeatures: Passes on the results of the geoprocessing so that they can be displayed.
    private func processFeatures(resultFeatures: GeoprocessingFeatures) {
        if let featureSet = resultFeatures.features {
            // Iterates through the feature set.
            for feature in featureSet.features().makeIterator() {
                // Creates the graphic for each feature's geometry.
                let graphic = Graphic(geometry: feature.geometry)
                // Sets the graphic on the overlay to display to the user.
                model.resultGraphicsOverlay.addGraphic(graphic)
            }
        }
    }
}

private extension ShowViewshedFromPointOnMapView {
    class Model: ObservableObject {
        /// A map with topographic basemap.
        /// Sets map's initial viewpoint to Vanoise National Park in France.
        let map: Map = {
            let map = Map(basemapStyle: .arcGISTopographic)
            map.initialViewpoint = Viewpoint(
                center: Point(latitude: 45.379, longitude: 6.849),
                scale: 144447
            )
            return map
        }()
        
        /// The processing task that references the online resource through the url.
        let geoprocessingTask = GeoprocessingTask(url: .viewshedURL)
        
        ///  The graphics overlay that displays the viewshed for the tapped location.
        var resultGraphicsOverlay = {
            let resultGraphicsOverlay = GraphicsOverlay()
            let fillColor = UIColor(
                red: 226 / 255.0,
                green: 119 / 255.0,
                blue: 40 / 255,
                alpha: 120 / 255.0
            )
            let fillSymbol = SimpleFillSymbol(
                style: .solid,
                color: fillColor,
                outline: nil
            )
            let resultRenderer = SimpleRenderer(symbol: fillSymbol)
            resultGraphicsOverlay.renderer = resultRenderer
            return resultGraphicsOverlay
        }()
        
        /// The graphics overlay that shows where the user tapped on the screen.
        var inputGraphicsOverlay = {
            let inputGraphicsOverlay = GraphicsOverlay()
            // Red dot marker that is added to graphic overlay on map on the location where the user taps.
            let pointSymbol = SimpleMarkerSymbol(style: .circle, color: .red, size: 10)
            // Sets the renderer to draw the dot symbol on the graphics overlay.
            let renderer = SimpleRenderer(symbol: pointSymbol)
            inputGraphicsOverlay.renderer = renderer
            return inputGraphicsOverlay
        }()
        
        /// Handles the execution of the geoprocessing task and gets the result.
        var geoprocessingJob: GeoprocessingJob?
        
        /// Removes previously tapped location from overlay and draws new dot on tap location.
        /// - Parameter point: Location that the user tapped on the map.
        func addGraphic(at point: Point) {
            inputGraphicsOverlay.removeAllGraphics()
            let graphic = Graphic(geometry: point)
            inputGraphicsOverlay.addGraphic(graphic)
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
