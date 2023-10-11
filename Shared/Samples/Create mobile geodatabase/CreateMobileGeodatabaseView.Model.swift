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
        
        /// A URL to a temporary geodatabase.
        private let geodatabaseURL: URL
        
        /// A URL to a temporary directory to store the geodatabase.
        private let directoryURL: URL
        
        /// The mobile geodatabase.
        private var geodatabase: Geodatabase?
        
        /// The feature table in the geodatabase.
        private var featureTable: GeodatabaseFeatureTable?
        
        /// The table description used to create a new feature table in the geodatabase.
        private let tableDescription: TableDescription = {
            // Create a description for the feature table.
            let description = TableDescription(
                name: "LocationHistory",
                spatialReference: .wgs84,
                geometryType: Point.self
            )
            
            // Create and add the field descriptions for the table.
            description.addFieldDescriptions([
                // `FieldType.OID` is the primary key of the SQLite table.
                FieldDescription(name: "oid", fieldType: .oid),
                // `FieldType.DATE` is the date column used to store a calendar date.
                FieldDescription(name: "collection_timestamp", fieldType: .date)
            ])
            
            // Set unnecessary properties to false.
            description.hasAttachments = false
            description.hasM = false
            description.hasZ = false
            
            return description
        }()
        
        /// The list of features in the feature table.
        @Published private(set) var features: [FeatureItem] = []
        
        /// The count of features in the feature table.
        @Published private(set) var featureCount = 0
        
        /// A Boolean value indicating whether to show an error alert.
        @Published var isShowingErrorAlert = false
        
        /// The error shown in the error alert.
        @Published private(set) var error: Error? {
            didSet { isShowingErrorAlert = error != nil }
        }
        
        init() {
            // Create the temporary directory using file manager.
            directoryURL = FileManager
                .default
                .temporaryDirectory
                .appendingPathComponent(ProcessInfo().globallyUniqueString)
            try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: false)
            
            // Create the geodatabase path with the directory URL.
            geodatabaseURL = directoryURL
                .appendingPathComponent("LocationHistory", isDirectory: false)
                .appendingPathExtension("geodatabase")
        }
        
        deinit {
            try? FileManager.default.removeItem(at: directoryURL)
        }
        
        // MARK: Methods
        
        /// Creates a mobile geodatabase with a feature table.
        func createGeodatabase() async {
            do {
                // Remove the geodatabase file if it already exists.
                if FileManager.default.fileExists(atPath: geodatabaseURL.path) {
                    try FileManager.default.removeItem(at: geodatabaseURL)
                }
                
                // Create an empty mobile geodatabase at the given URL.
                geodatabase = try await Geodatabase.createEmpty(fileURL: geodatabaseURL)
                
                // Create a new feature table in the geodatabase using a table description.
                if let table = try await geodatabase?.makeTable(description: tableDescription) {
                    // Load the feature table.
                    try await table.load()
                    featureTable = table
                    
                    // Create a feature layer using the table and add it to the map.
                    let featureLayer = FeatureLayer(featureTable: table)
                    map.addOperationalLayer(featureLayer)
                }
            } catch {
                self.error = error
            }
        }
        
        /// Adds a feature to the feature table at a given map point.
        /// - Parameter mapPoint: The map point used to make the feature.
        func addFeature(at mapPoint: Point) async {
            guard let featureTable else { return }
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
        
        /// Updates the list of features by queiring the feature table.
        func updateFeatures() async {
            guard let featureTable else { return }
            do {
                // Query the geodatabase feature table.
                let results = try await featureTable.queryFeatures(using: QueryParameters())
                
                // Create a feature item for each feature in the query results.
                features = results.features().compactMap { feature in
                    if let oid = feature.attributes["oid"] as? Int64,
                       let timeStamp = feature.attributes["collection_timestamp"] as? Date {
                        return FeatureItem(oid: oid, timestamp: timeStamp)
                    }
                    return nil
                }
            } catch {
                self.error = error
            }
        }
        
        /// Presents the sheet containing options to share the geodatabase.
        func presentShareSheet() {
            // Create the activity view controller with the geodatabase URL.
            let activityViewController = UIActivityViewController(
                activityItems: [geodatabaseURL],
                applicationActivities: nil
            )

            // Present the activity view controller.
            let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
            windowScene?.keyWindow?.rootViewController?.present(activityViewController, animated: true)
            
            // Reset the geodatabase once it has been shared.
            activityViewController.completionWithItemsHandler = { [weak self] _, completed, _, error in
                if completed {
                    Task { [weak self] in
                        await self?.resetGeodatabase()
                    }
                } else if let error {
                    self?.error = error
                }
            }
        }
        
        /// Removes all the existing features and creates a new geodatabase.
        private func resetGeodatabase() async {
            // Close the geodatabase to cease all adjustments.
            geodatabase?.close()
            
            // Remove the current features and layers.
            features.removeAll()
            featureCount = 0
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
        let timestamp: Date
    }
}
