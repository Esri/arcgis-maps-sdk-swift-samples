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
    /// The graphics overlay that shows where the user tapped on the screen.
    @State private var inputGraphicsOverlay = {
        let inputGraphicsOverlay = GraphicsOverlay()
        // Red dot marker that is added to graphic overlay on map on the location where the user taps.
        let pointSymbol = SimpleMarkerSymbol(style: .circle, color: .red, size: 10)
        // Sets the renderer to draw the dot symbol on the graphics overlay.
        let renderer = SimpleRenderer(symbol: pointSymbol)
        inputGraphicsOverlay.renderer = renderer
        return inputGraphicsOverlay
    }()
    /// The graphics overlay that displays the viewshed for the tapped location.
    @State private var resultGraphicsOverlay = {
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
    /// The current draw status of the map.
    @State private var currentDrawStatus: Bool = false
    /// The processing task that references the online resource through the url.
    @State private var geoprocessingTask: GeoprocessingTask = {
        let geoprocess = GeoprocessingTask(url: .viewshedURL)
        return geoprocess
    }()
    /// Handles the execution of the geoprocessing task and gets the result.
    @State private var geoprocessingJob: GeoprocessingJob?
    /// Sets map's initial viewpoint to Vanoise National Park in France.
    @State private var map: Map = {
        let map = Map(basemapStyle: .arcGISTopographicBase)
        map.initialViewpoint = Viewpoint(
            center: Point(latitude: 45.3790902612337, longitude: 6.84905317262762),
            scale: 1444407
        )
        return map
    }()
    
    var body: some View {
        MapView(map: map, graphicsOverlays: [inputGraphicsOverlay, resultGraphicsOverlay])
            .onSingleTapGesture { _, tapPoint in
                self.tapScreenPoint = tapPoint
            }
            .overlay(alignment: .center) {
                // Sets locating indication when currentDrawStatus is true.
                if currentDrawStatus == true {
                    ProgressView("Drawing…")
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                        .shadow(radius: 50)
                }
            }
            .task(id: tapScreenPoint) {
                guard let tapScreenPoint else { return }
                currentDrawStatus = true
                // Sets current draw status to false after process tap point operation
                // completes.
                defer { currentDrawStatus = false }
                await process(at: tapScreenPoint)
            }
            .errorAlert(presentingError: $error)
    }
    
    private func process(at tapScreenPoint: Point) async {
        addGraphic(at: tapScreenPoint)
        await calculateViewshed(at: tapScreenPoint)
    }
    
    /// Removes previously tapped location from overlay and draws new dot on tap location.
    private func addGraphic(at tapPoint: Point) {
        inputGraphicsOverlay.removeAllGraphics()
        let graphic = Graphic(geometry: tapPoint)
        inputGraphicsOverlay.addGraphic(graphic)
    }
    
    private func calculateViewshed(at point: Point) async {
        // Clears previously viewshed drawing.
        resultGraphicsOverlay.removeAllGraphics()
        // If there is a geoprocessing job in progress it is cancelled.
        await geoprocessingJob?.cancel()
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
        geoprocessingJob = geoprocessingTask.makeJob(parameters: params)
        geoprocessingJob?.start()
        // Get the result of the geoprocessing job asynchronously.
        let result = await geoprocessingJob?.result
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
    private func processFeatures(resultFeatures: GeoprocessingFeatures) {
        if let featureSet = resultFeatures.features {
            // Iterates through the feature set.
            for feature in featureSet.features().makeIterator() {
                // Creates the graphic for each feature's geometry.
                let graphic = Graphic(geometry: feature.geometry)
                // Sets the graphic on the overlay to display to the user.
                resultGraphicsOverlay.addGraphic(graphic)
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
