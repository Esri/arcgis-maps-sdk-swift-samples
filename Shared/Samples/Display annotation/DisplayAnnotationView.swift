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

struct DisplayAnnotationView: View {
    /// A map with a light grey basemap centered on East Lothian in Scotland.
    @State private var map: Map = {
        let map = Map(basemapStyle: .arcGISLightGray)
        map.initialViewpoint = Viewpoint(latitude: 55.882436, longitude: -2.725610, scale: 72_223.819286)
        return map
    }()
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    var body: some View {
        // Create a map view with a map.
        MapView(map: map)
            .task {
                do {
                    // Create a feature layer.
                    let featureTable = ServiceFeatureTable(url: .eastLothianRivers)
                    try await featureTable.load()
                    let featureLayer = FeatureLayer(featureTable: featureTable)
                    
                    // Create an annotation layer.
                    let annotationLayer = AnnotationLayer(url: .riversAnnotation)
                    try await annotationLayer.load()
                    
                    // Add both layers to the map as operational layers.
                    map.addOperationalLayers([featureLayer, annotationLayer])
                } catch {
                    // Present an alert for an error loading a layer.
                    self.error = error
                }
            }
            .errorAlert(presentingError: $error)
    }
}

private extension URL {
    /// A URL to a feature layer for the rivers in East Lothian.
    static var eastLothianRivers: URL {
        URL(string: "https://services1.arcgis.com/6677msI40mnLuuLr/arcgis/rest/services/East_Lothian_Rivers/FeatureServer/0")!
    }
    
    /// A URL to an annotation layer for the rivers in East Lothian.
    static var riversAnnotation: URL {
        URL(string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/RiversAnnotation/FeatureServer/0")!
    }
}

#Preview {
    DisplayAnnotationView()
}
