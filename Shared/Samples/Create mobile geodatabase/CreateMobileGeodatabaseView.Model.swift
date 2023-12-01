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
import UniformTypeIdentifiers

extension CreateMobileGeodatabaseView {
    // MARK: Model
    
    /// The model used to store the geo model and other expensive objects used in the view.
    @MainActor
    class Model: ObservableObject {
        /// A map with a topographic basemap centered on Harpers Ferry, WV, USA.
        let map: Map = {
            let map = Map(basemapStyle: .arcGISTopographic)
            map.initialViewpoint = Viewpoint(latitude: 39.3238, longitude: -77.7332, scale: 1e4)
            return map
        }()
        
        /// A geodatabase file that can be exported with the system's file exporter.
        let geodatabaseFile = GeodatabaseFile()
        
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
            
            return description
        }()
        
        /// The list of features in the feature table.
        @Published private(set) var features = [FeatureItem]()
        
        /// Creates a new feature table from a geodatabase.
        func createFeatureTable() async throws {
            // Create a new geodatabase.
            try await geodatabaseFile.createGeodatabase()
            
            // Create a feature table in the geodatabase using a table description.
            guard let table = try await geodatabaseFile.geodatabase?.makeTable(
                description: tableDescription
            ) else { return }
            featureTable = table
            
            // Create a feature layer using the table and add it to the map.
            let featureLayer = FeatureLayer(featureTable: table)
            map.addOperationalLayer(featureLayer)
        }
        
        /// Adds a feature to the feature table at a given map point.
        /// - Parameter mapPoint: The map point used to make the feature.
        func addFeature(at mapPoint: Point) async throws {
            guard let featureTable else { return }
            
            // Create an attribute with the current date.
            let attributes = ["collection_timestamp": Date()]
            
            // Create a feature with the attributes and point.
            let feature = featureTable.makeFeature(attributes: attributes, geometry: mapPoint)
            
            // Add the feature to the feature table.
            try await featureTable.add(feature)
            
            // Add the feature to the list of features.
            if let oid = feature.attributes["oid"] as? Int64,
               let timeStamp = feature.attributes["collection_timestamp"] as? Date {
                features.append(FeatureItem(oid: oid, timestamp: timeStamp))
            }
        }
        
        /// Removes all the existing features from the map.
        func resetFeatures() throws {
            // Delete the geodatabase.
            try geodatabaseFile.deleteGeodatabase()
            
            // Remove the current features and layers.
            features.removeAll()
            map.removeAllOperationalLayers()
        }
    }
    
    /// A struct representing a feature in the feature table.
    struct FeatureItem: Hashable {
        /// The primary key of the feature in the SQLite table.
        let oid: Int64
        /// The collection timestamp of the the feature.
        let timestamp: Date
    }
    
    // MARK: GeodatabaseFile
    
    /// A geodatabase file that can be used with the native file exporter.
    final class GeodatabaseFile {
        /// The mobile geodatabase used to create the geodatabase file.
        private(set) var geodatabase: Geodatabase?
        
        /// A URL to the temporary geodatabase file.
        private let geodatabaseURL: URL
        
        /// A URL to the temporary directory containing the geodatabase file.
        private let directoryURL: URL
        
        init() {
            // Create the temporary directory using file manager.
            directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(
                ProcessInfo().globallyUniqueString
            )
            try? FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: false
            )
            
            // Create the geodatabase path with the directory URL.
            geodatabaseURL = directoryURL
                .appendingPathComponent("LocationHistory", isDirectory: false)
                .appendingPathExtension("geodatabase")
        }
        
        deinit {
            try? FileManager.default.removeItem(at: directoryURL)
        }
        
        /// Creates an empty mobile geodatabase file.
        func createGeodatabase() async throws {
            // Create an empty mobile geodatabase at the given URL.
            geodatabase = try await Geodatabase.createEmpty(fileURL: geodatabaseURL)
        }
        
        /// Deletes the geodatabase file.
        func deleteGeodatabase() throws {
            // Close the geodatabase to cease all adjustments.
            geodatabase?.close()
            
            // Remove the geodatabase file if it exists.
            if FileManager.default.fileExists(atPath: geodatabaseURL.path) {
                try FileManager.default.removeItem(at: geodatabaseURL)
            }
        }
    }
}

extension CreateMobileGeodatabaseView.GeodatabaseFile: FileDocument {
    /// The file and data types that the document reads from.
    static var readableContentTypes = [UTType.geodatabase]
    
    /// Creates a document and initializes it with the contents of a file.
    convenience init(configuration: ReadConfiguration) throws {
        fatalError("Loading geodatabase files is not supported by this sample.")
    }
    
    /// Serializes a document snapshot to a file wrapper.
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return try FileWrapper(url: geodatabaseURL)
    }
}

extension UTType {
    /// A type that represents a geodatabase file.
    static var geodatabase: Self {
        UTType(filenameExtension: "geodatabase")!
    }
}
