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

struct ApplyDictionaryRendererToFeatureLayerView: View {
    /// A map with a topographic basemap.
    @State private var map = Map(basemapStyle: .arcGISTopographic)
    
    /// The viewpoint for zooming the map view to the feature layers.
    @State private var viewpoint: Viewpoint?
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    var body: some View {
        MapView(map: map, viewpoint: viewpoint)
            .task {
                do {
                    // Creates the feature layers and adds them to the map when the sample opens.
                    let featureLayers = try await makeMIL2525DFeatureLayers()
                    map.addOperationalLayers(featureLayers)
                    
                    // Zooms the viewpoint to the feature layers using their extents.
                    let layerExtents = featureLayers.compactMap(\.fullExtent)
                    if let combinedExtents = GeometryEngine.combineExtents(of: layerExtents) {
                        viewpoint = Viewpoint(boundingGeometry: combinedExtents)
                    }
                } catch {
                    self.error = error
                }
            }
            .errorAlert(presentingError: $error)
    }
    
    /// Creates a list of feature layers with mil2525d symbols.
    /// - Returns: A list of new `FeatureLayer` objects.
    private func makeMIL2525DFeatureLayers() async throws -> [FeatureLayer] {
        // Creates and loads a geodatabase from a local file.
        let geodatabase = Geodatabase(fileURL: .militaryOverlayGeodatabase)
        try await geodatabase.load()
        
        // Creates and loads a mil2525d dictionary symbol style from a local file.
        let mil2525dDictionarySymbolStyle = DictionarySymbolStyle(url: .mil2525dStyleFile)
        try await mil2525dDictionarySymbolStyle.load()
        
        // Creates feature layers from the geodatabase's feature tables.
        let featureLayers = geodatabase.featureTables.map { featureTable in
            let featureLayer = FeatureLayer(featureTable: featureTable)
            
            // Sets the layer's renderer to display the features using mil2525d symbols.
            featureLayer.renderer = DictionaryRenderer(
                dictionarySymbolStyle: mil2525dDictionarySymbolStyle
            )
            featureLayer.minScale = 1000000
            return featureLayer
        }
        await featureLayers.load()
        
        return featureLayers
    }
}

private extension URL {
    /// The URL to the local "Joint Military Symbology MIL-STD-2525D" mobile style file.
    static var mil2525dStyleFile: URL {
        Bundle.main.url(forResource: "mil2525d", withExtension: "stylx")!
    }
    
    /// The URL to the local "Military Overlay" geodatabase file.
    static var militaryOverlayGeodatabase: URL {
        Bundle.main.url(
            forResource: "militaryoverlay",
            withExtension: "geodatabase",
            subdirectory: "militaryoverlay.geodatabase"
        )!
    }
}
