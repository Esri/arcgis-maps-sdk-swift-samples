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
    @State private var error: Error?
    @State private var isLoading = false
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
                        model.relatedSelectedFeature = nil
                        guard let parksLayer = model.parksFeatureLayer else { return }
                        parksLayer.clearSelection()
                        model.calloutPlacement = nil
                        do {
                            let identifyResult = try await mapView.identify(on: parksLayer, screenPoint: screenPoint, tolerance: 5)
                            if let identifiedFeature = identifyResult.geoElements.first as? ArcGISFeature {
                                parksLayer.selectFeature(identifiedFeature)
                                model.selectedFeature = identifiedFeature
                                try await model.queryRelatedFeatures(for: identifiedFeature, tappedScreenPoint: screenPoint)
                                model.calloutVisible = true
                                model.calloutPlacement = .location(self.model.mapPoint!)
                                await mapView.setViewpointCenter(mapPoint)
                            }
                        } catch {
                            self.error = error
                        }
                    }
                }
                .callout(placement: $model.calloutPlacement) { _ in
                    if model.calloutVisible {
                        calloutContent
                    }
                }
                .task {
                    isLoading = true
                    do {
                        try await model.loadFeatures()
                        await mapView.setViewpoint(
                            Viewpoint(latitude: 65.399121, longitude: -151.521682, scale: 50000000)
                        )
                    } catch {
                        self.error = error
                    }
                    isLoading = false
                }
                .overlay(alignment: .center) {
                    if isLoading {
                        loadingView
                    }
                }
                .errorAlert(presentingError: $error)
        }
    }
    
    var calloutContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(model.parkName)")
                .font(.headline)
            if !model.attributeValue.isEmpty {
                Text("Annual Visitors:")
                Picker("Annual Visitors", selection: $model.selectedVisitorValue) {
                    ForEach(model.visitorOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: model.selectedVisitorValue) { _ , newValue in
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
        var map = Map(basemapStyle: .arcGISTopographic)
        var calloutVisible = true
        var parksFeatureLayer: FeatureLayer?
        var parksFeatureTable: ServiceFeatureTable?
        var preservesTable: ServiceFeatureTable?
        var selectedFeature: ArcGISFeature?
        var relatedSelectedFeature: ArcGISFeature?
        var calloutPlacement: CalloutPlacement?
        var screenPoint: CGPoint?
        var mapPoint: Point?
        var attributeValue: String = ""
        var parkName: String = ""
        var visitorOptions = ["0-1,000", "1,000–10,000", "10,000-50,000", "50,000-100,000", "100,000+"]
        var selectedVisitorValue: String = "0-1,000"
        
        func loadFeatures() async throws {
            let geodatabase = ServiceGeodatabase(url: .alaskaParksFeatureService)
            try await geodatabase.load()
            parksFeatureTable = geodatabase.table(withLayerID: 1)
            if let parksTable = parksFeatureTable {
                parksFeatureLayer = FeatureLayer(featureTable: parksTable)
                map.addOperationalLayer(parksFeatureLayer!)
            }
            preservesTable = geodatabase.table(withLayerID: 0)
            if let preservesTable = preservesTable {
                let preservesLayer = FeatureLayer(featureTable: preservesTable)
                map.addOperationalLayer(preservesLayer)
            }
        }
        
        func setSelectedFeatureUpdate(_ newValue: String) async throws {
            if let feature = relatedSelectedFeature {
                try await updateRelatedFeature(feature: feature, newValue: newValue)
            }
        }
        
        func updateRelatedFeature(feature: ArcGISFeature, newValue: String) async throws {
            try await feature.load()
            feature.setAttributeValue(newValue, forKey: .annualVisitorsKey)
            attributeValue = newValue
            try await self.preservesTable?.update(feature)
            if let geodatabase = preservesTable?.serviceGeodatabase {
                let editResults = try await geodatabase.applyEdits()
                if let first = editResults.first,
                   first.editResults[0].didCompleteWithErrors == false {
                    parksFeatureLayer?.clearSelection()
                    calloutPlacement = .location(mapPoint!)
                }
            }
        }
        
        func queryRelatedFeatures(for feature: ArcGISFeature, tappedScreenPoint: CGPoint) async throws {
            guard let parksTable = parksFeatureTable else { return }
            let attributes = feature.attributes
            // Set higher level park name in case there are no related results
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
