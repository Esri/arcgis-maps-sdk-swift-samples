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

extension EditGeodatabaseWithTransactionsView {
    /// The view model for the sample.
    @MainActor
    class Model: ObservableObject {
        /// A map with an oceans basemap.
        let map: Map = {
            let map = Map(basemapStyle: .arcGISOceans)
            map.initialViewpoint = Viewpoint(
                center: Point(x: -95.2043, y: 29.0699, spatialReference: .wgs84),
                scale: 8e4
            )
            return map
        }()
        
        /// The local geodatabase to edit.
        let geodatabase: Geodatabase
        
        /// A URL to a temporary file containing the geodatabase.
        private let temporaryGeodatabaseURL = FileManager.createTemporaryDirectory()
            .appending(component: "SaveTheBay.geodatabase")
        
        init() {
            try? FileManager.default.copyItem(at: .saveTheBay, to: temporaryGeodatabaseURL)
            geodatabase = Geodatabase(fileURL: temporaryGeodatabaseURL)
        }
        
        deinit {
            // Removes the temporary directory and geodatabase file.
            let temporaryDirectoryURL = temporaryGeodatabaseURL.deletingLastPathComponent()
            try? FileManager.default.removeItem(at: temporaryDirectoryURL)
        }
        
        /// Sets up geodatabase tables and map layers.
        func setUp() async throws {
            try await geodatabase.load()
            
            // Adds the geodatabase's tables to the map as feature layers.
            let featureLayers = geodatabase.featureTables
                .map(FeatureLayer.init(featureTable:))
            map.addOperationalLayers(featureLayers)
            
            // Sets feature tables' display names.
            let marineTable = geodatabase.featureTables.first {
                $0.tableName == "Save_The_Bay_Marine_Sync"
            }
            marineTable?.displayName = "Marine"
            
            let birdTable = geodatabase.featureTables.first {
                $0.tableName == "Save_The_Bay_Birds_Sync"
            }
            birdTable?.displayName = "Bird"
        }
        
        /// Creates and adds a feature to a table in the geodatabase.
        /// - Parameters:
        ///   - tableName: The name of the table in the geodatabase.
        ///   - featureTypeName: The name of the type of feature to create.
        ///   - point: The point on the map to add the feature at.
        func addFeature(tableName: String, featureTypeName: String, point: Point) async throws {
            guard let featureTable = geodatabase.featureTables.first(
                where: { $0.tableName == tableName }
            ), let featureType = featureTable.featureTypes.first(
                where: { $0.name == featureTypeName }
            ) else { return }
            
            let feature = featureTable.makeFeature(type: featureType, geometry: point)
            try await featureTable.add(feature)
        }
    }
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
    /// The URL for the "Save The Bay" geodatabase file in the bundle.
    static var saveTheBay: URL {
        Bundle.main.url(forResource: "SaveTheBay", withExtension: "geodatabase")!
    }
}
