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

extension EditAndSyncFeaturesWithFeatureServiceView {
    /// The view model for the sample.
    @MainActor
    final class Model: ObservableObject {
        // MARK: Properties
        
        /// The generated local geodatabase to edit.
        @Published private(set) var geodatabase: Geodatabase?
        
        /// The job being performed.
        @Published private(set) var currentJob: Job?
        
        /// A map with a San Fransisco streets basemap.
        let map: Map = {
            let tiledLayer = ArcGISTiledLayer(url: .sanFranciscoStreetsTilePackage)
            let basemap = Basemap(baseLayer: tiledLayer)
            return Map(basemap: basemap)
        }()
        
        /// The feature currently selected by the user.
        private(set) var selectedFeature: Feature?
        
        /// The task for generating and synchronizing the geodatabase with the feature service.
        private let geodatabaseSyncTask = GeodatabaseSyncTask(url: .wildfireSyncFeatureServer)
        
        /// A URL to the temporary file containing the geodatabase.
        private let temporaryGeodatabaseURL = FileManager
            .createTemporaryDirectory()
            .appending(component: "WildfireSync.geodatabase")
        
        deinit {
            // Removes the temporary geodatabase file and its directory.
            let temporaryDirectoryURL = temporaryGeodatabaseURL.deletingLastPathComponent()
            try? FileManager.default.removeItem(at: temporaryDirectoryURL)
        }
        
        // MARK: Methods
        
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
            
            await addPointFeatureLayers(featureTables: featureTables)
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
            let generateGeodatabaseJob = geodatabaseSyncTask.makeGenerateGeodatabaseJob(
                parameters: parameters,
                downloadFileURL: temporaryGeodatabaseURL
            )
            
            // Generates the geodatabase.
            try await runJob(generateGeodatabaseJob) {
                geodatabase = try await generateGeodatabaseJob.output
            }
            try await geodatabase?.load()
            
            // Adds the geodatabase's feature tables to the map.
            map.removeAllOperationalLayers()
            await addPointFeatureLayers(featureTables: geodatabase!.featureTables)
        }
        
        /// Synchronizes the geodatabase and feature service.
        func syncGeodatabase() async throws {
            guard let geodatabase else { return }
            
            // Creates the default parameters for synchronizing the geodatabase.
            let syncParameters = try await geodatabaseSyncTask.makeDefaultSyncGeodatabaseParameters(
                geodatabase: geodatabase
            )
            
            // Creates the sync job using the parameters.
            let syncGeodatabaseJob = geodatabaseSyncTask.makeSyncGeodatabaseJob(
                parameters: syncParameters,
                geodatabase: geodatabase
            )
            
            // Synchronizes the geodatabase with the feature service.
            try await runJob(syncGeodatabaseJob) {
                _ = try await syncGeodatabaseJob.output
            }
        }
        
        /// Selects the first feature in a list of identify layer results.
        /// - Parameter identifyLayerResults: The results containing the feature.
        func selectFeature(identifyLayerResults: [IdentifyLayerResult]) {
            guard let feature = identifyLayerResults.first?.geoElements.first as? Feature,
                  let featureLayer = feature.table?.layer as? FeatureLayer else { return  }
            
            featureLayer.selectFeature(feature)
            selectedFeature = feature
        }
        
        /// Moves the selected feature to a given map point.
        /// - Parameter point: The point on the map.
        func moveSelectedFeature(point: Point) async throws {
            guard let selectedFeature else { return }
            
            selectedFeature.geometry = point
            try await selectedFeature.table?.update(selectedFeature)
            
            clearSelection()
        }
        
        /// Resets the sample.
        func reset() async {
            await cancelJob()
            geodatabase = nil
            clearSelection()
            map.removeAllOperationalLayers()
        }
        
        /// Cancels the current job.
        func cancelJob() async {
            await currentJob?.cancel()
            currentJob = nil
        }
        
        /// Runs a given job.
        /// - Parameters:
        ///   - job: The job to run.
        ///   - onStartAction: The action to run after the job is started.
        private func runJob(_ job: Job, onStartAction: () async throws -> Void) async throws {
            currentJob = job
            defer { currentJob = nil }
            
            job.start()
            try await onStartAction()
        }
        
        /// Adds to feature layers created from given feature tables with a `Point` geometry type to the map.
        /// - Parameter featureTables: The feature tables.
        private func addPointFeatureLayers(featureTables: [FeatureTable]) async {
            await featureTables.load()
            
            // Creates feature layers from the tables that have a `Point` geometry type.
            let pointFeatureLayers = featureTables
                .filter { $0.geometryType == Point.self }
                .map(FeatureLayer.init(featureTable:))
            
            map.addOperationalLayers(pointFeatureLayers)
        }
        
        /// Clears the selected feature.
        private func clearSelection() {
            let featureLayer = selectedFeature?.table?.layer as? FeatureLayer
            featureLayer?.clearSelection()
            
            selectedFeature = nil
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
