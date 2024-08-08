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
        /// The current progress of the running job.
        @Published private(set) var progress: Progress?
        
        /// A map with an oceans basemap.
        let map: Map = {
            let map = Map(basemapStyle: .arcGISOceans)
            map.initialViewpoint = Viewpoint(center: .christmasBay.center, scale: 8e4)
            return map
        }()
        
        /// The local geodatabase to edit.
        private(set) var geodatabase: Geodatabase!
        
        /// The task for generating and synchronizing the geodatabase with the feature service.
        private let geodatabaseSyncTask = GeodatabaseSyncTask(url: .saveTheBaySync)
        
        /// The parameters for synchronizing the geodatabase and the feature service.
        private var syncGeodatabaseParameters: SyncGeodatabaseParameters?
        
        /// A URL to a temporary directory where the geodatabase file is stored.
        private let temporaryDirectoryURL = FileManager.createTemporaryDirectory()
        
        /// A Boolean value indicating whether a transaction is active on the geodatabase.
        var hasLocalEdits: Bool {
            geodatabase?.hasLocalEdits ?? false
        }
        
        deinit {
            // Removes the temporary directory and geodatabase file.
            try? FileManager.default.removeItem(at: temporaryDirectoryURL)
        }
        
        /// Sets up geodatabase and map.
        func setUp() async throws {
            geodatabase = try await makeGeodatabase()
            
            // Creates the default parameters for synchronizing the geodatabase.
            syncGeodatabaseParameters = try await geodatabaseSyncTask.makeDefaultSyncGeodatabaseParameters(
                geodatabase: geodatabase
            )
            
            // Adds the geodatabase's tables to the map as feature layers.
            await geodatabase.featureTables.load()
            
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
        
        /// Synchronizes the geodatabase and feature service.
        func syncGeodatabase() async throws {
            guard let syncGeodatabaseParameters else { return }
            
            // Creates the sync job using the parameters.
            let syncGeodatabaseJob = geodatabaseSyncTask.makeSyncGeodatabaseJob(
                parameters: syncGeodatabaseParameters,
                geodatabase: geodatabase
            )
            progress = syncGeodatabaseJob.progress
            defer { progress = nil }
            
            // Synchronizes the geodatabase with the feature service.
            syncGeodatabaseJob.start()
            _ = try await syncGeodatabaseJob.output
        }
        
        /// Makes a geodatabase using the geodatabase sync task.
        /// - Returns: A new `Geodatabase` object.
        private func makeGeodatabase() async throws -> Geodatabase {
            // Creates the parameters for generating the geodatabase from the sync task.
            let parameters = try await geodatabaseSyncTask.makeDefaultGenerateGeodatabaseParameters(
                extent: .christmasBay
            )
            parameters.outSpatialReference = map.spatialReference
            
            let areaLayerOption = parameters.layerOptions.first { $0.layerID == 2 }!
            parameters.removeLayerOption(areaLayerOption)
            
            // Creates the job to generate the geodatabase.
            let temporaryGeodatabaseURL = temporaryDirectoryURL
                .appending(component: "SaveTheBay.geodatabase")
            let generateGeodatabaseJob = geodatabaseSyncTask.makeGenerateGeodatabaseJob(
                parameters: parameters,
                downloadFileURL: temporaryGeodatabaseURL
            )
            progress = generateGeodatabaseJob.progress
            defer { progress = nil }
            
            // Generates the geodatabase.
            generateGeodatabaseJob.start()
            let geodatabase = try await generateGeodatabaseJob.output
            try await geodatabase.load()
            
            return geodatabase
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

private extension Geometry {
    /// The area around Christmas Bay, TX, USA.
    static var christmasBay: Envelope {
        Envelope(
            xRange: -95.3035 ... -95.1053,
            yRange: 29.0100 ... 29.1298,
            spatialReference: .wgs84
        )
    }
}

private extension URL {
    /// The URL for the "Save the Bay Sync" feature server.
    static var saveTheBaySync: URL {
        URL(string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/Sync/SaveTheBaySync/FeatureServer")!
    }
}
