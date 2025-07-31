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
import Foundation

extension GenerateGeodatabaseReplicaFromFeatureServiceView {
    /// The view model for the sample.
    @MainActor
    @Observable
    final class Model {
        /// The generated local geodatabase to edit.
        private(set) var geodatabase: Geodatabase?
        
        /// The generate geodatabase job.
        private(set) var generateGeodatabaseJob: GenerateGeodatabaseJob?
        
        /// A map with a San Fransisco streets basemap.
        let map: Map = {
            let tiledLayer = ArcGISTiledLayer(url: .sanFranciscoStreetsTilePackage)
            let basemap = Basemap(baseLayer: tiledLayer)
            return Map(basemap: basemap)
        }()
        
        /// The task for generating and synchronizing the geodatabase with the feature service.
        private let geodatabaseSyncTask = GeodatabaseSyncTask(
            url: .wildfireSyncFeatureServer
        )
        
        /// A URL to the temporary file containing the geodatabase.
        private let temporaryGeodatabaseURL = FileManager
            .createTemporaryDirectory()
            .appending(component: "WildfireSync.geodatabase")
        
        deinit {
            // Removes the temporary geodatabase file and its directory.
            let temporaryDirectoryURL = temporaryGeodatabaseURL.deletingLastPathComponent()
            try? FileManager.default.removeItem(at: temporaryDirectoryURL)
        }
        
        /// Adds feature layers from the feature service to the map.
        func setUpMap() async throws {
            try await geodatabaseSyncTask.load()
            
            // Creates feature tables from the feature service.
            guard let layerInfos = geodatabaseSyncTask.featureServiceInfo?.layerInfos else { return }
            let featureTableURLs = layerInfos.compactMap { layerInfo -> URL? in
                guard let id = layerInfo.id else { return nil }
                return .wildfireSyncFeatureServer.appendingPathComponent("\(id)")
            }
            let featureTables = featureTableURLs.map(ServiceFeatureTable.init(url:))
            let featureLayers = featureTables.map(FeatureLayer.init(featureTable:))
            map.addOperationalLayers(featureLayers)
        }
        
        /// Generates a geodatabase from the feature service.
        /// - Parameter extent: The extent of the data to be included in the generated geodatabase.
        func generateGeodatabase(extent: Envelope) async throws {
            // Creates the parameters for generating the geodatabase.
            let parameters = try await geodatabaseSyncTask.makeDefaultGenerateGeodatabaseParameters(
                extent: extent
            )
            parameters.returnsAttachments = false
            
            // Creates the job to generate the geodatabase.
            generateGeodatabaseJob = geodatabaseSyncTask.makeGenerateGeodatabaseJob(
                parameters: parameters,
                downloadFileURL: temporaryGeodatabaseURL
            )
            defer {
                generateGeodatabaseJob = nil
            }
            guard let generateGeodatabaseJob else { return }
            
            // Generates the geodatabase.
            generateGeodatabaseJob.start()
            geodatabase = try await generateGeodatabaseJob.output
            guard let geodatabase else { return }
            try await geodatabase.load()
            
            map.removeAllOperationalLayers()
            
            // Adds the geodatabase's tables to the map as feature layers.
            let featureLayers = geodatabase.featureTables
                .map(FeatureLayer.init(featureTable:))
            map.addOperationalLayers(featureLayers)
            
            // Unregister geodatabase since we are not editing or syncing features.
            try await geodatabaseSyncTask.unregisterGeodatabase(geodatabase)
        }
        
        /// Cancels the generate geodatabase job.
        func cancelJob() async {
            // Cancels the generate geodatabase job.
            await generateGeodatabaseJob?.cancel()
            generateGeodatabaseJob = nil
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
    /// The URL to the local streets tile package of San Francisco, CA, USA.
    static var sanFranciscoStreetsTilePackage: URL {
        Bundle.main.url(forResource: "SanFrancisco", withExtension: "tpkx")!
    }
    /// The URL to the Wildfire Sync feature server.
    static var wildfireSyncFeatureServer: URL {
        URL(string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/Sync/WildfireSync/FeatureServer")!
    }
}
