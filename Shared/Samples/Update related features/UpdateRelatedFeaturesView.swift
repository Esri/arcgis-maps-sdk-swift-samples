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
    @State private var selectedFeature: ArcGISFeature?
    @State private var calloutPlacement: CalloutPlacement?
    
    var body: some View {
        MapViewReader { mapView in
            MapView(map: map)
                .onSingleTapGesture { screenPoint, mapPoint in
                    Task {
                        guard
                            let parksLayer = parksFeatureLayer,
                            let parksTable = parksFeatureTable
                        else { return }
                        
                        // Clear previous selection and callout
                        parksLayer.clearSelection()
                        calloutPlacement = nil
                        
                        do {
                            let identifyResult = try await mapView.identify(on: parksLayer, screenPoint: screenPoint, tolerance: 5)
                            
                            if let identifiedFeature = identifyResult.geoElements.first as? ArcGISFeature {
                                // Select the feature on the layer
                                parksLayer.selectFeature(identifiedFeature)
                                selectedFeature = identifiedFeature
                                
                                // Show callout at feature location
                                calloutPlacement = .geoElement(identifiedFeature)
                                
                                // Query related features (your existing method)
                                await queryRelatedFeatures(for: identifiedFeature, parksTable: parksTable)
                            } else {
                                // No feature found, hide callout
                                calloutPlacement = nil
                            }
                        } catch {
                            print("Error identifying features: \(error.localizedDescription)")
                        }
                    }
                }
                .callout(placement: $calloutPlacement) { placement in
                    if let feature = selectedFeature,
                       let parkName = feature.attributes["UNIT_NAME"] as? String {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Preserve: \(parkName)")
                                .font(.headline)
                            
                        }
                        .padding()
                    }
                }
                .task {
                    do {
                        let geodatabase = ServiceGeodatabase(url: .alaskaParksFeatureService)
                        try await geodatabase.load()
                        
                        let preservesTable = geodatabase.table(withLayerID: 0)
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
                        await mapView.setViewpoint(Viewpoint(latitude: 65.399121, longitude: -151.521682, scale: 50000000))
                    } catch {
                        print("Error loading geodatabase: \(error.localizedDescription)")
                    }
                }
        }
    }
    
    func queryRelatedFeatures(for feature: ArcGISFeature, parksTable: ServiceFeatureTable) async {
        do {
            let relatedResults = try await parksTable.queryRelatedFeatures(to: feature)
            for relatedResult in relatedResults {
                for geoElement in relatedResult.features() {
                    if let relatedFeature = geoElement as? ArcGISFeature {
                        print("Related feature: \(relatedFeature.attributes)")
                        
                    }
                }
            }
        } catch {
            print("Error querying related features: \(error.localizedDescription)")
        }
    }
}

extension URL {
    static var alaskaParksFeatureService: URL {
        URL(string: "https://services2.arcgis.com/ZQgQTuoyBrtmoGdP/ArcGIS/rest/services/AlaskaNationalParksPreserves_Update/FeatureServer")!
    }
}
