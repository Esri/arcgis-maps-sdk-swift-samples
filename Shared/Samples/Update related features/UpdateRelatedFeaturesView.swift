// Copyright 2025 Esri
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
import ArcGISToolkit
import SwiftUI

struct UpdateRelatedFeaturesView: View {
    /// The error shown in the error alert.
    @State private var error: (any Error)?
    /// A Boolean value indicating whether the feature data is being loaded.
    @State private var isLoading = false
    /// The model that holds the data for displaying and updating the view.
    @State private var model = Model()
    
    var body: some View {
        MapViewReader { mapView in
            MapView(map: model.map)
                .onSingleTapGesture { screenPoint, mapPoint in
                    model.screenPoint = screenPoint
                    model.mapPoint = mapPoint
                    Task {
                        isLoading = true
                        defer { isLoading = false }
                        model.clearAll()
                        // Ensure parks feature layer is available and clear it.
                        guard let parksLayer = model.parksFeatureLayer else { return }
                        parksLayer.clearSelection()
                        do {
                            let identifyResult = try await mapView.identify(
                                on: parksLayer,
                                screenPoint: screenPoint,
                                tolerance: 5
                            )
                            // If a feature is found, select and query related data.
                            if let identifiedFeature = identifyResult.geoElements.first as? ArcGISFeature {
                                parksLayer.selectFeature(identifiedFeature)
                                model.selectedFeature = identifiedFeature
                                // Query for related preserve data.
                                try await model.queryRelatedFeatures(
                                    for: identifiedFeature
                                )
                                // Display a callout at the feature's location.
                                model.calloutVisible = true
                                model.calloutPlacement = .location(model.mapPoint!)
                                // Center the map on the tapped feature.
                                await mapView.setViewpointCenter(mapPoint)
                            }
                        } catch {
                            self.error = error
                        }
                    }
                }
            // Show a callout with editable content when a feature is selected.
                .callout(placement: $model.calloutPlacement) { _ in
                    if model.calloutVisible {
                        calloutContent
                    }
                }
            // Load initial map and data when the view appears.
                .task {
                    isLoading = true
                    defer { isLoading = false }
                    do {
                        try await model.loadFeatures()
                        // Set initial viewpoint to Alaska.
                        await mapView.setViewpoint(
                            Viewpoint(latitude: 65.399121, longitude: -151.521682, scale: 50000000)
                        )
                    } catch {
                        self.error = error
                    }
                }
            // Show a loading spinner when `isLoading` is true.
                .overlay(alignment: .center) {
                    if isLoading {
                        loadingView
                    }
                }
            // Display error alerts, if needed.
                .errorAlert(presentingError: $error)
        }
    }
    
    var calloutContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(model.parkName)")
                .font(.headline)
            if !model.attributeValue.isEmpty {
                Text("Annual Visitors:")
                // Picker to allow the user to update visitor range.
                Picker("Annual Visitors", selection: $model.selectedVisitorValue) {
                    ForEach(model.visitorOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: model.selectedVisitorValue) { _, newValue in
                    Task {
                        do {
                            try await self.model.setSelectedFeatureUpdate(newValue)
                        } catch {
                            self.error = error
                        }
                    }
                }
            }
        }
        .padding()
    }
    
    /// The loading indicator overlay shown during data fetches.
    var loadingView: some View {
        ProgressView(
               """
               Fetching
               data
               """
        )
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 10))
        .shadow(radius: 50)
        .multilineTextAlignment(.center)
    }
}

extension UpdateRelatedFeaturesView {
    @MainActor
    @Observable
    class Model {
        /// A map with a topographic basemap style.
        var map = Map(basemapStyle: .arcGISTopographic)
        
        /// A boolean value the reflects whether the callout should be shown or not.
        var calloutVisible = false
        
        /// Feature layers and tables for parks and preserves
        var parksFeatureLayer: FeatureLayer?
        var parksFeatureTable: ServiceFeatureTable?
        var preservesTable: ServiceFeatureTable?
        
        /// Selected features and related features.
        var selectedFeature: ArcGISFeature?
        var relatedSelectedFeature: ArcGISFeature?
        
        /// The location of the callout on the map.
        var calloutPlacement: CalloutPlacement?
        var screenPoint: CGPoint?
        var mapPoint: Point?
        var attributeValue: String = ""
        var parkName: String = ""
        var visitorOptions = ["0-1,000", "1,000–10,000", "10,000-50,000", "50,000-100,000", "100,000+"]
        var selectedVisitorValue: String = "0-1,000"
        
        /// Clear selected data and callout.
        func clearAll() {
            relatedSelectedFeature = nil
            attributeValue = ""
            calloutPlacement = nil
        }
        
        /// Load the feature tables and add them to the map.
        func loadFeatures() async throws {
            let geodatabase = ServiceGeodatabase(url: .alaskaParksFeatureService)
            try await geodatabase.load()
            // Load parks layer
            parksFeatureTable = geodatabase.table(withLayerID: 1)
            if let parksTable = parksFeatureTable {
                parksFeatureLayer = FeatureLayer(featureTable: parksTable)
                map.addOperationalLayer(parksFeatureLayer!)
            }
            // Load preserves layer
            preservesTable = geodatabase.table(withLayerID: 0)
            if let preservesTable = preservesTable {
                let preservesLayer = FeatureLayer(featureTable: preservesTable)
                map.addOperationalLayer(preservesLayer)
            }
        }
        
        /// Updates the related feature's "Annual Visitors" attribute with the selected value.
        func setSelectedFeatureUpdate(_ newValue: String) async throws {
            if let feature = relatedSelectedFeature {
                try await updateRelatedFeature(feature: feature, newValue: newValue)
            }
        }
        
        /// Performs the actual update to the related feature and applies the edits.
        func updateRelatedFeature(feature: ArcGISFeature, newValue: String) async throws {
            try await feature.load()
            feature.setAttributeValue(newValue, forKey: .annualVisitorsKey)
            attributeValue = newValue
            try await preservesTable?.update(feature)
            // Apply edits to the service geodatabase
            if let geodatabase = preservesTable?.serviceGeodatabase {
                let editResults = try await geodatabase.applyEdits()
                if let first = editResults.first,
                   first.editResults[0].didCompleteWithErrors == false {
                    parksFeatureLayer?.clearSelection()
                    calloutPlacement = .location(mapPoint!)
                }
            }
        }
        
        /// Queries related features (preserves) for a selected park.
        func queryRelatedFeatures(for feature: ArcGISFeature) async throws {
            guard let parksTable = parksFeatureTable else { return }
            let attributes = feature.attributes
            // Default to park name from the selected park feature.
            parkName = attributes[.unitKey] as? String ?? "Unknown"
            // reset attribute value in case there are no related feature results.
            attributeValue = ""
            let relatedResultsQuery = try await parksTable.queryRelatedFeatures(to: feature)
            for relatedResult in relatedResultsQuery {
                for relatedFeature in relatedResult.features() {
                    if let relatedArcGISFeature = relatedFeature as? ArcGISFeature {
                        let attributes = relatedArcGISFeature.attributes
                        attributeValue = attributes[.annualVisitorsKey] as? String ?? ""
                        parkName = attributes[.unitKey] as? String ?? "Unknown"
                        selectedVisitorValue = attributeValue
                        relatedSelectedFeature = relatedArcGISFeature
                    }
                }
            }
        }
    }
}

extension String {
    static var annualVisitorsKey: String {
        "ANNUAL_VISITORS"
    }
    
    static var unitKey: String {
        "UNIT_NAME"
    }
}

extension URL {
    static var alaskaParksFeatureService: URL {
        URL(string: "https://services2.arcgis.com/ZQgQTuoyBrtmoGdP/ArcGIS/rest/services/AlaskaNationalParksPreserves_Update/FeatureServer")!
    }
}
