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
import Foundation

extension EditFeaturesWithFeatureLinkedAnnotationView {
    /// The view model for the sample.
    @MainActor
    final class Model: ObservableObject {
        /// The feature currently selected by the user.
        @Published private(set) var selectedFeature: Feature?
        
        /// A map with a light gray basemap.
        let map: Map = {
            let map = Map(basemapStyle: .arcGISLightGray)
            
            // Initially centers the map in Loudoun Country, VA, USA.
            map.initialViewpoint = Viewpoint(latitude: 39.0204, longitude: -77.4159, scale: 2256)
            return map
        }()
        
        /// A URL to the temporary file containing the geodatabase.
        private let temporaryGeodatabaseURL = FileManager
            .createTemporaryDirectory()
            .appending(component: "LoudounAnno.geodatabase")
        
        /// The building number and street name of the selected feature.
        var selectedFeatureAddress: (buildingNumber: Int32?, streetName: String?) {
            let buildingNumber = selectedFeature?.attributes[.addressFieldKey] as? Int32
            let streetName = selectedFeature?.attributes[.streetNameFieldKey] as? String
            return (buildingNumber, streetName)
        }
        
        deinit {
            // Removes the temporary geodatabase file and its directory.
            let temporaryDirectoryURL = temporaryGeodatabaseURL.deletingLastPathComponent()
            try? FileManager.default.removeItem(at: temporaryDirectoryURL)
        }
        
        /// Adds feature and annotation layers created from geodatabase feature tables to the map.
        func setUpMap() async throws {
            // Creates a geodatabase from a file copied from the bundle.
            try FileManager.default.copyItem(at: .loudounAnnoGeodatabase, to: temporaryGeodatabaseURL)
            let geodatabase = Geodatabase(fileURL: temporaryGeodatabaseURL)
            try await geodatabase.load()
            
            // Creates feature and annotation layers from tables in the geodatabase.
            let featureTableNames = ["ParcelLines_1", "Loudoun_Address_Points_1"]
            let featureLayers = featureTableNames
                .compactMap { geodatabase.featureTable(named: $0) }
                .map(FeatureLayer.init)
            
            let annotationTableNames = ["ParcelLinesAnno_1", "Loudoun_Address_PointsAnno_1"]
            let annotationLayers = annotationTableNames
                .compactMap { geodatabase.annotationTable(named: $0) }
                .map(AnnotationLayer.init)
            
            // Adds the layers to the map.
            map.addOperationalLayers(featureLayers)
            map.addOperationalLayers(annotationLayers)
        }
        
        /// Selects the first feature in a given list of identify layer results.
        /// - Parameter results: The identify layer results.
        func selectFirstFeature(from results: [IdentifyLayerResult]) {
            clearSelectedFeature()
            
            // Gets the first feature from the first feature layer in the results.
            let featureLayerResult = results.first { $0.layerContent is FeatureLayer }
            guard let featureLayer = featureLayerResult?.layerContent as? FeatureLayer,
                  let feature = featureLayerResult?.geoElements.first as? ArcGISFeature else { return }
            
            featureLayer.selectFeature(feature)
            selectedFeature = feature
        }
        
        /// Sets the address attributes of the selected feature.
        /// - Parameters:
        ///   - buildingNumber: The number of the building for the `AD_ADDRESS` field.
        ///   - streetName: The name of street for the `ST_STR_NAM` field.
        func setFeatureAddress(buildingNumber: Int32?, streetName: String) async throws {
            selectedFeature?.setAttributeValue(buildingNumber, forKey: .addressFieldKey)
            selectedFeature?.setAttributeValue(streetName, forKey: .streetNameFieldKey)
            
            try await updateSelectedFeature()
        }
        
        /// Updates the selected feature's geometry using a given map point.
        /// - Parameter mapPoint: The point on the map.
        func updateFeatureGeometry(with mapPoint: Point) async throws {
            if selectedFeature?.geometry is Point {
                // Sets the feature's geometry to the map point if the feature is a point.
                selectedFeature?.geometry = mapPoint
            } else if let polyline = selectedFeature?.geometry as? Polyline,
                      let projectedPoint = GeometryEngine.project(mapPoint, into: polyline.spatialReference!),
                      let nearestVertex = GeometryEngine.nearestVertex(in: polyline, to: projectedPoint) {
                // Replaces the nearest vertex with the map point if the feature is a polyline.
                let polylineBuilder = PolylineBuilder(polyline: polyline)
                
                // Removes the nearest vertex from the polyline.
                polylineBuilder.parts[nearestVertex.partIndex!].points.remove(
                    at: nearestVertex.pointIndex!
                )
                
                // Adds the new point to the polyline and sets it to the selected feature's geometry.
                polylineBuilder.add(projectedPoint)
                selectedFeature?.geometry = polylineBuilder.toGeometry()
            }
            
            try await updateSelectedFeature()
            clearSelectedFeature()
        }
        
        /// Clears the selected feature.
        func clearSelectedFeature() {
            let featureLayer = selectedFeature?.table?.layer as? FeatureLayer
            featureLayer?.clearSelection()
            selectedFeature = nil
        }
        
        /// Updates the selected feature in its feature table.
        private func updateSelectedFeature() async throws {
            guard let selectedFeature else { return }
            try await selectedFeature.table?.update(selectedFeature)
        }
    }
}

private extension String {
    /// The key for the address attribute field.
    static var addressFieldKey: String { "AD_ADDRESS" }
    /// The key for the street name attribute field.
    static var streetNameFieldKey: String { "ST_STR_NAM" }
}

private extension FileManager {
    /// Creates a temporary directory.
    /// - Returns: The URL of the created directory.
    static func createTemporaryDirectory() -> URL {
        // swiftlint:disable:next force_try
        try! FileManager.default.url(
            for: .itemReplacementDirectory,
            in: .userDomainMask,
            appropriateFor: FileManager.default.temporaryDirectory,
            create: true
        )
    }
}

private extension URL {
    /// The URL to the local "Loudoun Anno" geodatabase file.
    static var loudounAnnoGeodatabase: URL {
        Bundle.main.url(forResource: "loudoun_anno", withExtension: "geodatabase")!
    }
}
