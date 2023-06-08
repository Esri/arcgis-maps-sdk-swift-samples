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

struct IdentifyLayerFeaturesView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// The tapped screen point.
    @State var tapScreenPoint: CGPoint!
    
    var body: some View {
        ZStack {
            MapViewReader { proxy in
                MapView(map: model.map)
                    .onSingleTapGesture { screenPoint, _ in
                        tapScreenPoint = screenPoint
                    }
                    .task {
                        do {
                            // Add map image layer.
                            let mapImageLayer = ArcGISMapImageLayer(url: .worldCities)
                            try await mapImageLayer.load()
                            
                            // Hide continent and world layers.
                            mapImageLayer.subLayerContents[1].isVisible = false
                            mapImageLayer.subLayerContents[2].isVisible = false
                            model.map.addOperationalLayer(mapImageLayer)
                            
                            // Add feature layer.
                            let featureTable = ServiceFeatureTable(url: .damageAssessment)
                            try await featureTable.load()
                            let featureLayer = FeatureLayer(featureTable: featureTable)
                            model.map.addOperationalLayer(featureLayer)
                        } catch {
                            model.error = error
                        }
                    }
                    .task(id: tapScreenPoint) {
                        // Identify layers using the screen point.
                        if let screenPoint = tapScreenPoint,
                           let results = try? await proxy.identifyLayers(
                            screenPoint: screenPoint,
                            tolerance: 12,
                            returnPopupsOnly: false,
                            maximumResultsPerLayer: 10) {
                            model.handleIdentifyResults(results)
                            model.isShowingLayerAlert = true
                        }
                    }
                    .alert(isPresented: $model.isShowingLayerAlert) {
                        Alert(
                            title: Text(model.layerAlertTitle),
                            message: Text(model.layerAlertMessage)
                        )
                    }
                    .alert(isPresented: $model.isShowingErrorAlert, presentingError: model.error)
            }
        }
    }
}

private extension IdentifyLayerFeaturesView {
    /// The view model for the sample.
    class Model: ObservableObject {
        /// A map with a topographic basemap centered on the United States..
        let map: Map = {
            let map = Map(basemapStyle: .arcGISTopographic)
            
            // Center the map on the USA.
            map.initialViewpoint = Viewpoint(
                center: Point(x: -10977012.785807, y: 4514257.550369, spatialReference: .webMercator),
                scale: 68015210
            )
            return map
        }()
        
        /// A Boolean value indicating whether to show a layer alert.
        @Published var isShowingLayerAlert = false
        
        /// The title for the identify layer result alert.
        @Published var layerAlertTitle = ""
        
        /// The message for the identify layer result alert.
        @Published var layerAlertMessage = ""
        
        /// A Boolean value indicating whether to show an error alert.
        @Published var isShowingErrorAlert = false
        
        /// The error shown in the error alert.
        @Published var error: Error? {
            didSet { isShowingErrorAlert = error != nil }
        }
        
        /// Update the identify layer result alert text based on the identify layer results.
        /// - Parameter results: An `IdentifyLayerResult Array` to handle.
        func handleIdentifyResults(_ results: [IdentifyLayerResult]) {
            var alertMessageString = ""
            var totalGeoElementsCount = 0
            
            for (iCount, identifyLayerResult) in results.enumerated() {
                // Create alert message the from geoElement count and the layer name.
                let geoElementsCount = geoElementsCountFromResult(identifyLayerResult)
                let layerName = identifyLayerResult.layerContent.name
                alertMessageString.append("\(layerName): \(geoElementsCount)")
                
                // Add new line character if not the final element in array.
                if iCount != results.count - 1 {
                    alertMessageString.append("\n")
                }
                
                // Update total count.
                totalGeoElementsCount += geoElementsCount
            }
            
            if totalGeoElementsCount > 0 {
                // Show the results if any elements were found.
                layerAlertTitle = "Number of elements found"
                layerAlertMessage = alertMessageString
            } else {
                // Notify user that no elements were found.
                layerAlertTitle = "No element found"
                layerAlertMessage = ""
            }
        }
        
        /// Count the geoElements from an identify layer result.
        /// - Parameter result: The `IdentifyLayerResult` to count.
        /// - Returns: An `Int` count of the geoElements
        private func geoElementsCountFromResult(_ result: IdentifyLayerResult) -> Int {
            var tempResults = [result]
            
            // Using Depth First Search approach to handle recursion.
            var count = 0
            var index = 0
            
            while index < tempResults.count {
                // Get the result object from the array.
                let identifyResult = tempResults[index]
                
                // Update count with geoElements from the result.
                count += identifyResult.geoElements.count
                
                // Check if the result has any sublayer results. If so, add those
                // result objects in the tempResults array after the current result.
                if !identifyResult.sublayerResults.isEmpty {
                    tempResults.insert(contentsOf: identifyResult.sublayerResults, at: index + 1)
                }
                
                // Update the count and repeat.
                index += 1
            }
            
            return count
        }
    }
}

private extension URL {
    /// A world cities image layer URL.
    static var worldCities: URL {
        URL(string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/SampleWorldCities/MapServer")!
    }
    
    /// A damage assessment feature layer URL.
    static var damageAssessment: URL {
        URL(string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/DamageAssessment/FeatureServer/0")!
    }
}
