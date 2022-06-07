// Copyright 2022 Esri
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

import SwiftUI
import ArcGIS

struct SelectFeaturesInFeatureLayerView: View {
    /// An array of selected features.
    @State private var selectedFeatures = [Feature]()
    
    /// A feature layer.
    @State private var featureLayer = makeFeatureLayer()
    
    /// A Boolean value indicating whether to show an alert.
    @State private var showAlert = false
    
    /// The error to display in the alert.
    @State private var error: Error?
    
    /// A map with a topographic basemap style and initial viewpoint.
    @StateObject private var map = makeMap()
    
    /// Creates a feature layer.
    private static func makeFeatureLayer() -> FeatureLayer {
        let featureServiceURL = URL(string: "https://services1.arcgis.com/4yjifSiIG17X0gW4/arcgis/rest/services/GDP_per_capita_1960_2016/FeatureServer/0")!
        let featureTable = ServiceFeatureTable(url: featureServiceURL)
        return FeatureLayer(featureTable: featureTable)
    }
    
    /// Creates a map.
    private static func makeMap() -> Map {
        let map = Map(basemapStyle: .arcGISTopographic)
        map.initialViewpoint = Viewpoint(
            center: Envelope(
                xMin: -180,
                yMin: -90,
                xMax: 180,
                yMax: 90,
                spatialReference: .wgs84
            ).center,
            scale: 2e8
        )
        return map
    }
    
    /// Asynchronously loads the feature layer and adds it to the operational layer of the map.
    /// Toggles an alert displaying an error if loading fails.
    private func loadFeatureLayer() async {
        do {
            // Loads the feature layer.
            try await featureLayer.load()
            
            // Adds the feature layer to the operational layer of the map.
            map.addOperationalLayer(featureLayer)
        } catch {
            // Toggles the alert and updates the error.
            showAlert.toggle()
            self.error = error
        }
    }
    
    /// Handles the identification and selection of features in the feature layer.
    /// Toggles an alert displaying an error if identification fails.
    private func handleSelection(for mapViewProxy: MapViewProxy, at screenPoint: CGPoint) {
        Task {
            do {
                // Saves the results from the identify method on
                // the map view proxy.
                let results = try await mapViewProxy.identify(
                    layer: featureLayer,
                    screenPoint: screenPoint,
                    tolerance: 12,
                    maximumResults: 10
                )
                
                // Unselects the selected features.
                featureLayer.unselect(features: selectedFeatures)
                
                // Updates the selected features to
                // the geo elements from the results.
                selectedFeatures = results.geoElements as! [Feature]
                
                // Selects the features from the selected features array.
                featureLayer.select(features: selectedFeatures)
            } catch {
                // Toggles the alert and updates the error.
                showAlert.toggle()
                self.error = error
            }
        }
    }
    
    var body: some View {
        MapViewReader { mapViewProxy in
            MapView(map: map)
                .onSingleTapGesture { screenPoint, _ in
                    handleSelection(for: mapViewProxy, at: screenPoint)
                }
                .overlay(alignment: .top) {
                    Text("\(selectedFeatures.count) feature(s) selected.")
                        .padding(.top)
                }
                .alert(isPresented: $showAlert, presentingError: error)
                .task {
                    await loadFeatureLayer()
                }
        }
    }
}

struct SelectFeaturesInFeatureLayerView_Previews: PreviewProvider {
    static var previews: some View {
        SelectFeaturesInFeatureLayerView()
    }
}
