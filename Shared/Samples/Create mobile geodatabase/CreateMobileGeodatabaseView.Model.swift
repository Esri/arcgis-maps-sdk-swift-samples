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

extension CreateMobileGeodatabaseView {
    /// The view model for the sample.
    @MainActor
    class Model: ObservableObject {
        // MARK: Properties
        
        /// A map with a topographic basemap centered on Harpers Ferry, West Virginia, USA.
        let map: Map = {
            let map = Map(basemapStyle: .arcGISTopographic)
            map.initialViewpoint = Viewpoint(latitude: 39.3238, longitude: -77.7332, scale: 1e4)
            return map
        }()
        
        /// A URL to the temporary geodatabase.
        private let geodatabaseURL: URL
        
        /// A URL to a temporary directory to store the geodatabase.
        private let directoryURL: URL
        
        /// The mobile geodatabase.
        private var geodatabase: Geodatabase?
        
        /// The geodatabase feature table created in the geodatabase.
        private var featureTable: GeodatabaseFeatureTable?
        
        /// The table description used to create a new feature table in the geodatabase.
        private let tableDescription: TableDescription = {
            // Create a description for the feature table.
            let description = TableDescription(
                name: "LocationHistory",
                spatialReference: .wgs84,
                geometryType: Point.self
            )
            
            // Create and add the description fields for the table.
            // `FieldType.OID` is the primary key of the SQLite table.
            // `FieldType.DATE` is a date column used to store a calendar date.
            // `FieldDescription`s can be a SHORT, INTEGER, GUID, FLOAT, DOUBLE, DATE, TEXT, OID, GLOBALID, BLOB, GEOMETRY, RASTER, or XML.
            let fieldDescriptions = [
                FieldDescription(name: "oid", fieldType: .oid),
                FieldDescription(name: "collection_timestamp", fieldType: .date)
            ]
            description.addFieldDescriptions(fieldDescriptions)
            
            // Set any unnecessary properties to false.
            description.hasAttachments = false
            description.hasM = false
            description.hasZ = false
            
            return description
        }()
        
        /// The list of features in the feature table.
        @Published private(set) var features: [FeatureItem] = []
        
        /// The count of features on the feature table.
        @Published private(set) var featureCount = 0
        
        /// A Boolean value indicating whether to show an error alert.
        @Published var isShowingErrorAlert = false
        
        /// The error shown in the error alert.
        @Published private(set) var error: Error? {
            didSet { isShowingErrorAlert = error != nil }
        }
        
        init() {
            // Create the temporary directory.
            directoryURL = FileManager.default
                .temporaryDirectory
                .appendingPathComponent(ProcessInfo().globallyUniqueString)
            try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: false)
            
            // Create the geodatabase path.
            geodatabaseURL = directoryURL
                .appendingPathComponent("LocationHistory", isDirectory: false)
                .appendingPathExtension("geodatabase")
        }
        
        deinit {
            try? FileManager.default.removeItem(at: directoryURL)
        }
        
        // MARK: Methods
        
        /// Creates the mobile geodatabase.
        func createGeodatabase() async {
            do {
                // Remove the file if it already exists.
                if FileManager.default.fileExists(atPath: geodatabaseURL.path) {
                    try FileManager.default.removeItem(at: geodatabaseURL)
                }
                
                // Create the mobile geodatabase at the given URL.
                geodatabase = try await Geodatabase.createEmpty(fileURL: geodatabaseURL)
                
                // Add a new table to the geodatabase by creating one from the table description.
                if let table = try await geodatabase?.makeTable(description: tableDescription) {
                    // Load the table.
                    try await table.load()
                    featureTable = table
                    
                    // Create a feature layer using the table.
                    let featureLayer = FeatureLayer(featureTable: table)
                    
                    // Add the feature layer to the map's operational layers.
                    map.addOperationalLayer(featureLayer)
                }
            } catch {
                self.error = error
            }
        }
        
        /// Updates the features list by queiring the feature table.
        func updateFeatures() async {
            guard let featureTable else { return }
            do {
                // Query the geodatabase feature table.
                let results = try await featureTable.queryFeatures(using: QueryParameters())
                
                // Create a feature item for each feature in the query results.
                features = results.features().compactMap { feature in
                    if let oid = feature.attributes["oid"] as? Int64,
                       let timeStamp = feature.attributes["collection_timestamp"] as? Date {
                        return FeatureItem(oid: oid, timeStamp: timeStamp)
                    }
                    return nil
                }
            } catch {
                self.error = error
            }
        }
        
        /// Adds a feature to the feature table at a given map point.
        func addFeature(at mapPoint: Point) async {
            guard let featureTable = featureTable else { return }
            do {
                // Create an attribute with the current date.
                let attributes = ["collection_timestamp": Date()]
                
                // Create a feature with the attributes and point.
                let feature = featureTable.makeFeature(attributes: attributes, geometry: mapPoint)
                
                // Add the feature to the feature table.
                try await featureTable.add(feature)
                
                // Update the feature count.
                featureCount = featureTable.numberOfFeatures
            } catch {
                self.error = error
            }
        }
        
        /// Removes existing operational layers and close the geodatabase.
        func resetMap() async {
            // Close the geodatabase to cease all adjustments.
            geodatabase?.close()
            
            // Remove the current feature layers.
            map.removeAllOperationalLayers()
            
            // Create a new mobile geodatabase.
            await createGeodatabase()
        }
    }
    
    /// A struct representing a feature in the feature table.
    struct FeatureItem: Hashable {
        /// The primary key of the feature in the SQLite table.
        let oid: Int64
        /// The collection timestamp of the the feature.
        let timeStamp: Date
    }
}
