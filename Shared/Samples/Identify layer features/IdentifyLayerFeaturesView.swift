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
    
    ///
    @State var tapScreenPoint: CGPoint!
    
    @State var isShowingProgress = false
    
    var body: some View {
        ZStack {
            MapViewReader { proxy in
                // Create a map view to display the map.
                MapView(map: model.map)
                    .onSingleTapGesture { screenPoint, _ in
                        isShowingProgress = true
                        tapScreenPoint = screenPoint
                    }
                    .task(id: tapScreenPoint) {
                        if let screenPoint = tapScreenPoint,
                           let results = try? await proxy.identifyLayers(
                            screenPoint: screenPoint,
                            tolerance: 12,
                            returnPopupsOnly: false,
                            maximumResultsPerLayer: 10) {
                            model.handleIdentifyResults(results)
                            model.isShowingLayerAlert = true
                        }
                        isShowingProgress = false
                    }
                    .alert(isPresented: $model.isShowingErrorAlert, presentingError: model.alertError)
                    .alert(isPresented: $model.isShowingLayerAlert) {
                        Alert(
                            title: Text(model.layerAlertTitle),
                            message: Text(model.layerAlertMessage)
                        )
                    }
            }
            ProgressView()
                .hidden(!isShowingProgress)
        }
    }
}

private extension IdentifyLayerFeaturesView {
    /// The view model for the sample.
    class Model: ObservableObject {
        /// A map
        var map: Map!
        
        /// A Boolean value indicating whether to show a layer alert.
        @Published var isShowingLayerAlert = false
        
        /// The title for layer feature alert.
        @Published var layerAlertTitle = ""
        
        @Published var layerAlert: Alert!
        
        /// The message for layer feature alert.
        @Published var layerAlertMessage = ""
        
        /// A Boolean value indicating whether to show an error alert.
        @Published var isShowingErrorAlert = false
        
        /// The error shown in the alert.
        @Published var alertError: Error? {
            didSet { isShowingErrorAlert = alertError != nil }
        }
        
        init() {
            map = makeMap()
        }
        
        /// Creates a map.
        private func makeMap() -> Map {
            // Create a map with a topographic basemap.
            let map = Map(basemapStyle: .arcGISTopographic)
            map.initialViewpoint = Viewpoint(
                center: Point(x: -10977012.785807, y: 4514257.550369, spatialReference: .webMercator),
                scale: 68015210
            )
            
            // Add map image layer.
            let mapImageLayer = ArcGISMapImageLayer(url: .worldCities)
            Task {
                do {
                    try await mapImageLayer.load()
                    // Hide Continent and World layers.
                    mapImageLayer.subLayerContents[1].isVisible = false
                    mapImageLayer.subLayerContents[2].isVisible = false
                } catch {
                    alertError = error
                }
            }
            map.addOperationalLayer(mapImageLayer)
            
            // Add feature layer.
            let featureTable = ServiceFeatureTable(url: .damageAssessment)
            Task {
                do {
                    try await featureTable.load()
                } catch {
                    alertError = error
                }
            }
            let featureLayer = FeatureLayer(featureTable: featureTable)
            map.addOperationalLayer(featureLayer)
            
            return map
        }
        
        func handleIdentifyResults(_ results: [IdentifyLayerResult]) {
            var messageString = ""
            var totalCount = 0
            for (i, identifyLayerResult) in results.enumerated() {
                let count = geoElementsCountFromResult(identifyLayerResult)
                let layerName = identifyLayerResult.layerContent.name
                messageString.append("\(layerName): \(count)")
                
                // Add new line character if not the final element in array.
                if i != results.count - 1 {
                    messageString.append(" \n ")
                }
                
                // Update total count.
                totalCount += count
            }
            
            if totalCount > 0 {
                // Show the results if any elements were found.
                layerAlertTitle = "Number of elements found"
                layerAlertMessage = messageString
            } else {
                // Notify user that no elements were found.
                layerAlertTitle = "No element found"
                layerAlertMessage = ""
            }
        }
        
        private func geoElementsCountFromResult(_ result: IdentifyLayerResult) -> Int {
            // Create temp array.
            var tempResults = [result]
            
            // Using Depth First Search approach to handle recursion.
            var count = 0
            var index = 0
            
            while index < tempResults.count {
                // Get the result object from the array.
                let identifyResult = tempResults[index]
                
                // Update count with geoElements from the result.
                count += identifyResult.geoElements.count
                
                // Check if the result has any sublayer results.
                // If yes then add those result objects in the tempResults
                // array after the current result.
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
    /// A world cities sample image layer URL.
    static var worldCities: URL {
        URL(string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/SampleWorldCities/MapServer")!
    }
    
    /// A damage assessment feature layer URL.
    static var damageAssessment: URL {
        URL(string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/DamageAssessment/FeatureServer/0")!
    }
}

private extension View {
    @ViewBuilder func hidden(_ hidden: Bool) -> some View {
        if hidden == true {
            self.hidden()
        } else {
            self
        }
    }
}
