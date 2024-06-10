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
    @State private var tapScreenPoint: Point?
    @State private var inputGraphicsOverlay = {
        let inputGraphicsOverlay = GraphicsOverlay()
        let pointSymbol = SimpleMarkerSymbol(style: .circle, color: .red, size: 10)
        let renderer = SimpleRenderer(symbol: pointSymbol)
        inputGraphicsOverlay.renderer = renderer
        return inputGraphicsOverlay
    }()
    
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
    
    @State private var geoprocessingTask: GeoprocessingTask = {
        let geoprocess = GeoprocessingTask(
            url: URL(
                string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/Elevation/ESRI_Elevation_World/GPServer/Viewshed"
            )!
        )
        return geoprocess
    }()
    
    @State private var geoprocessingJob: GeoprocessingJob!
    
    @State private var map: Map = {
        let map = Map(basemapStyle: .arcGISTopographicBase)
        map.initialViewpoint = Viewpoint(
            center: Point(latitude: 45.3790902612337, longitude: 6.84905317262762),
            scale: 144447
        )
        return map
    }()
    
    var body: some View {
        MapView(map: map, graphicsOverlays: [inputGraphicsOverlay, resultGraphicsOverlay])
            .onSingleTapGesture { _, tapPoint in
                self.tapScreenPoint = tapPoint
            }
            .overlay(alignment: .center) {
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
                await process(at: tapScreenPoint)
                currentDrawStatus = false
            }
            .errorAlert(presentingError: $error)
    }
    
    private func process(at tapScreenPoint: Point) async {
        self.addGraphic(at: tapScreenPoint)
        await self.calculateViewshed(at: tapScreenPoint)
    }
    
    private func addGraphic(at tappoint: Point) {
        inputGraphicsOverlay.removeAllGraphics()
        let graphic = Graphic(geometry: tappoint)
        inputGraphicsOverlay.addGraphic(graphic)
    }
    
    private func calculateViewshed(at point: Point) async {
        self.resultGraphicsOverlay.removeAllGraphics()
        await self.geoprocessingJob?.cancel()
        guard let spatialReference = point.spatialReference else { return }
        let featureCollectionTable = FeatureCollectionTable(
            fields: [Field](),
            geometryType: Point.self,
            spatialReference: spatialReference)
        do {
            let feature = featureCollectionTable.makeFeature(geometry: point)
            try await featureCollectionTable.add(feature)
            await self.performGeoprocessing(featureCollectionTable)
        } catch {
            self.error = error
        }
    }
    
    private func performGeoprocessing(_ featureCollectionTable: FeatureCollectionTable) async {
        let params = GeoprocessingParameters(executionType: .synchronousExecute)
        params.processSpatialReference = featureCollectionTable.spatialReference
        params.outputSpatialReference = featureCollectionTable.spatialReference
        let geoprocessingFeature = GeoprocessingFeatures(features: featureCollectionTable)
        params.setInputValue(geoprocessingFeature, forKey: "Input_Observation_Point")
        geoprocessingJob = geoprocessingTask.makeJob(parameters: params)
        geoprocessingJob.start()
        let result = await geoprocessingJob.result
        switch result {
        case .success(let output):
            if let resultFeatures = output.outputs["Viewshed_Result"] as? GeoprocessingFeatures {
                self.processFeatures(resultFeatures: resultFeatures)
            }
        case .failure(let errorDescription):
            self.error = errorDescription
        }
    }
    
    private func processFeatures(resultFeatures: GeoprocessingFeatures) {
        if let featureSet = resultFeatures.features {
            for feature in featureSet.features().makeIterator() {
                let graphic = Graphic(geometry: feature.geometry)
                self.resultGraphicsOverlay.addGraphic(graphic)
            }
        }
    }
}

#Preview {
    ShowViewshedFromPointOnMapView()
}
