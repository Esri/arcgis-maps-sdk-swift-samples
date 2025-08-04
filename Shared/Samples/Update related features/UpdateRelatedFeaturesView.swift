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
    @State private var map = Map(basemapStyle: .arcGISTopographic)
    @State private var parksFeatureLayer: FeatureLayer?
    @State private var parksFeatureTable: ServiceFeatureTable?
    @State private var preservesTable: ServiceFeatureTable?
    @State private var selectedFeature: ArcGISFeature?
    @State private var calloutPlacement: CalloutPlacement?
    @State private var screenPoint: CGPoint?
    @State private var mapPoint: Point?
    @State private var attributeValue: String = ""
    @State private var parkName: String = ""
    @State private var visitorOptions = ["0-1,000", "1,000–10,000", "10,000–100,000", "100,000+"]
    @State private var selectedVisitorValue: String = "0-1,000"
    @State private var error: Error?
    @State private var isLoading = false
    
    var body: some View {
        MapViewReader { mapView in
            MapView(map: map)
                .onSingleTapGesture { screenPoint, mapPoint in
                    self.screenPoint = screenPoint
                    self.mapPoint = mapPoint
                    Task {
                        guard let parksLayer = parksFeatureLayer else { return }
                        parksLayer.clearSelection()
                        calloutPlacement = nil
                        do {
                            let identifyResult = try await mapView.identify(
                                on: parksLayer,
                                screenPoint: screenPoint,
                                tolerance: 5
                            )
                            if let identifiedFeature = identifyResult.geoElements.first as? ArcGISFeature {
                                parksLayer.selectFeature(identifiedFeature)
                                selectedFeature = identifiedFeature
                                calloutPlacement = .geoElement(identifiedFeature)
                                await queryRelatedFeatures(
                                    for: identifiedFeature,
                                    tappedScreenPoint: screenPoint
                                )
                                await mapView.setViewpointCenter(mapPoint)
                            } else {
                                calloutPlacement = nil
                            }
                        } catch {
                            self.error = error
                        }
                    }
                }
                .callout(placement: $calloutPlacement) { _ in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Park: \(parkName)")
                            .font(.headline)
                        Picker("Annual Visitors", selection: $selectedVisitorValue) {
                            ForEach(visitorOptions, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: selectedVisitorValue) {
                            if let feature = self.selectedFeature,
                               selectedVisitorValue != attributeValue {
                                Task {
                                    await updateRelatedFeature(
                                        feature: feature,
                                        newValue: selectedVisitorValue
                                    )
                                }
                            }
                        }
                    }
                    .padding()
                }
            
                .task {
                    isLoading = true
                    do {
                        let geodatabase = ServiceGeodatabase(url: .alaskaParksFeatureService)
                        try await geodatabase.load()
                        preservesTable = geodatabase.table(withLayerID: 0)
                        parksFeatureTable = geodatabase.table(withLayerID: 1)
                        if let preservesTable = preservesTable {
                            let preservesLayer = FeatureLayer(featureTable: preservesTable)
                            map.addOperationalLayer(preservesLayer)
                        }
                        if let parksTable = parksFeatureTable {
                            let parksLayer = FeatureLayer(featureTable: parksTable)
                            parksFeatureLayer = parksLayer
                            map.addOperationalLayer(parksLayer)
                        }
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
    
    func queryRelatedFeatures(for feature: ArcGISFeature, tappedScreenPoint: CGPoint) async {
        guard let parksTable = parksFeatureTable else { return }
        do {
            let relatedResults = try await parksTable.queryRelatedFeatures(to: feature)
            for result in relatedResults {
                for relatedFeature in result.features() {
                    if let relatedArcGISFeature = relatedFeature as? ArcGISFeature {
                        self.selectedFeature = relatedArcGISFeature
                        let attributes = relatedArcGISFeature.attributes
                        self.parkName = attributes[.unitKey] as? String ?? "Unknown"
                        self.attributeValue = attributes[.annualVisitorsKey] as? String ?? ""
                        calloutPlacement = .location(self.mapPoint!)
                    }
                }
            }
        } catch {
            self.error = error
        }
    }
    
    func updateRelatedFeature(feature: ArcGISFeature, newValue: String) async {
        isLoading = true
        do {
            try await feature.load()
            feature.setAttributeValue(newValue, forKey: .annualVisitorsKey)
            attributeValue = newValue
            try await self.preservesTable?.update(feature)
            if let geodatabase = preservesTable?.serviceGeodatabase {
                let editResults = try await geodatabase.applyEdits()
                if let first = editResults.first, first.editResults[0].didCompleteWithErrors == false {
                    parksFeatureLayer?.clearSelection()
                    calloutPlacement = .location(self.mapPoint!)
                }
            }
        } catch {
            self.error = error
        }
        isLoading = false
    }
    
    var loadingView: some View {
        ProgressView(
               """
               Fetching data
               """
        )
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 10))
        .shadow(radius: 50)
        .multilineTextAlignment(.center)
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
