// Copyright 2022 Esri
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

extension DownloadPreplannedMapAreaView {
    @MainActor
    class Model: ObservableObject {
        /// The currently selected map.
        @Published var selectedMap: SelectedMap = .onlineWebMap {
            didSet {
                selectedMapDidChange(from: oldValue)
            }
        }
        
        /// The offline map of the downloaded preplanned map area.
        @Published private var offlineMap: Map?
        
        /// The map used in the map view.
        var map: Map { offlineMap ?? onlineMap }
        
        /// A portal item displaying the Naperville, IL water network.
        private let napervillePortalItem = PortalItem(
            portal: .arcGISOnline(connection: .anonymous),
            id: PortalItem.ID("acc027394bc84c2fb04d1ed317aac674")!
        )
        
        /// The online map of the Naperville water network.
        private let onlineMap: Map
        
        /// The offline map task.
        private let offlineMapTask: OfflineMapTask
        
        /// A URL to a temporary directory where the downloaded map packages are stored.
        private let temporaryDirectory: URL
    
        /// The offline map information.
        @Published var offlineMapModels: Result<[OfflineMapModel], Error>?
        
        /// All the offline map models or an empty array in the case of an error.
        var allOfflineMapModels: [OfflineMapModel] {
            guard case .success(let models) = offlineMapModels else {
                return []
            }
            return models
        }
        
        private var makeOfflineMapModelsTask: Task<Void, Never>?
        
        /// A Boolean value indicating if the offline content can be deleted.
        @Published var canRemoveDownloadedMaps = false
        
        init() {
            // Create temp dsirectory.
            temporaryDirectory = FileManager.createTemporaryDirectory()
            
            // Initializes the online map and offline map task.
            onlineMap = Map(item: napervillePortalItem)
            offlineMapTask = OfflineMapTask(portalItem: napervillePortalItem)
            
            // Get the preplanned map areas and map those to offline map infos.
            makeOfflineMapModelsTask = Task { [weak self] in
                await self?.makeOfflineMapModels()
                self?.makeOfflineMapModelsTask = nil
            }
        }
        
        /// Gets the preplanned map areas from the offline map task and creates the
        /// offline map models.
        func makeOfflineMapModels() async {
            self.offlineMapModels = await Result {
                try await offlineMapTask.preplannedMapAreas
                    .sorted(using: KeyPathComparator(\.portalItem.title))
                    .map {
                        OfflineMapModel(
                            preplannedMapArea: $0,
                            offlineMapTask: offlineMapTask,
                            temporaryDirectory: temporaryDirectory
                        )
                    }
            }
        }
        
        deinit {
            // Removes the temporary directory
            try? FileManager.default.removeItem(at: temporaryDirectory)
            
            // Cancel the task that is making the offline map models.
            makeOfflineMapModelsTask?.cancel()
        }
        
        /// Updates the displayed map based on the given preplanned map area. If the preplanned map
        /// area is not nil, the preplanned map area will be downloaded if necessary and updates the map
        /// to the currently selected preplanned map area. If the preplanned map area is nil, then the map
        /// is set to the online web map.
        private func selectedMapDidChange(from oldValue: SelectedMap) {
            switch selectedMap {
            case .onlineWebMap:
                offlineMap = nil
            case .offlineMap(let info):
                if info.canDownload {
                    // If we have not yet downloaded or started downloading, then kick off a
                    // download and reset selection to prevous selection since we have to download
                    // the offline map.
                    selectedMap = oldValue
                    Task { [weak self] in
                        await info.download()
                        self?.updateCanRemoveDownloadedMaps()
                    }
                } else if case .success(let mmpk) = info.result {
                    // If we have already downloaded, then open the map in the mmpk.
                    offlineMap = mmpk.maps.first
                } else {
                    // If we have a failure, then keep the online map selected.
                    selectedMap = oldValue
                }
            }
        }
        
        /// Updates the `canRemoveDownloadedMaps` state.
        func updateCanRemoveDownloadedMaps() {
            canRemoveDownloadedMaps = allOfflineMapModels.contains(where: \.downloadDidSucceed)
        }
        
        /// Cancels all current jobs.
        func cancelAllJobs() async {
            await withTaskGroup(of: Void.self) { group in
                allOfflineMapModels.forEach { model in
                    if model.isDownloading {
                        group.addTask {
                            await model.cancelDownloading()
                        }
                    }
                }
            }
        }
        
        // Removes all downloaded maps.
        func removeDownloadedMaps() {
            // Sets the current map to the online web map.
            selectedMap = .onlineWebMap
            
            // Update state.
            canRemoveDownloadedMaps = false
            
            Task {
                // Cancel all current download jobs.
                await cancelAllJobs()
                
                // Remove each download.
                allOfflineMapModels.forEach { $0.removeDownloadedContent() }
            }
        }
    }
}

extension DownloadPreplannedMapAreaView.Model {
    /// A type that specifies the currently selected map.
    enum SelectedMap: Hashable {
        /// The online version of the map.
        case onlineWebMap
        /// One of the offline maps.
        case offlineMap(OfflineMapModel)
    }
}

/// An object that encapsulates state about an offline map.
class OfflineMapModel: ObservableObject, Identifiable {
    /// The preplanned map area.
    let preplannedMapArea: PreplannedMapArea
    /// The task to use to take the area offline.
    let offlineMapTask: OfflineMapTask
    /// The directory where the mmpk will be stored.
    let mmpkDirectory: URL
    /// The currently running download job.
    @Published var job: DownloadPreplannedOfflineMapJob?
    /// The result of the download job.
    @Published var result: Result<MobileMapPackage, Error>?
    
    init(preplannedMapArea: PreplannedMapArea, offlineMapTask: OfflineMapTask, temporaryDirectory: URL) {
        self.preplannedMapArea = preplannedMapArea
        self.offlineMapTask = offlineMapTask
        self.mmpkDirectory = temporaryDirectory
            .appendingPathComponent(preplannedMapArea.portalItem.id.rawValue)
            .appendingPathExtension("mmpk")
    }
    
    deinit {
        Task { [job] in
            // Cancel any outstanding job.
            await job?.cancel()
        }
    }
}

extension OfflineMapModel: Hashable {
    static func == (lhs: OfflineMapModel, rhs: OfflineMapModel) -> Bool {
        lhs === rhs
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

extension OfflineMapModel {
    /// A Boolean value indicating whether the map is being taken offline.
    var isDownloading: Bool {
        job != nil
    }
}

@MainActor
private extension OfflineMapModel {
    /// Downloads the given preplanned map area.
    /// - Parameter preplannedMapArea: The preplanned map area to be downloaded.
    /// - Precondition: `canDownload`
    func download() async {
        precondition(canDownload)
        
        let parameters: DownloadPreplannedOfflineMapParameters
        
        do {
            // Creates the parameters for the download preplanned offline map job.
            parameters = try await makeParameters(area: preplannedMapArea)
        } catch {
            // If creating the parameters fails, set the failure.
            self.result = .failure(error)
            return
        }
            
        // Creates the download preplanned offline map job.
        let job = offlineMapTask.makeDownloadPreplannedOfflineMapJob(
            parameters: parameters,
            downloadDirectory: mmpkDirectory
        )
        
        self.job = job
        
        // Starts the job.
        job.start()
        
        // Awaits the output of the job and assigns the result.
        result = await job.result.map { $0.mobileMapPackage }
        
        // Set the job to nil
        self.job = nil
    }
    
    /// A Boolean value indicating whether the offline map can be downloaded.
    /// This returns `false` if the map was already downloaded successfully or is in the process
    /// of being downloaded.
    var canDownload: Bool {
        !(isDownloading || downloadDidSucceed)
    }
    
    /// A Boolean value indicating whether the download succeeded.
    var downloadDidSucceed: Bool {
        if case .success = result {
            return true
        } else {
            return false
        }
    }
    
    /// Creates the parameters for a download preplanned offline map job.
    /// - Parameter preplannedMapArea: The preplanned map area to create parameters for.
    /// - Returns: A `DownloadPreplannedOfflineMapParameters` if there are no errors.
    func makeParameters(area: PreplannedMapArea) async throws -> DownloadPreplannedOfflineMapParameters {
        // Creates the default parameters.
        let parameters = try await offlineMapTask.makeDefaultDownloadPreplannedOfflineMapParameters(preplannedMapArea: area)
        // Sets the update mode to no updates as the offline map is display-only.
        parameters.updateMode = .noUpdates
        return parameters
    }
    
    /// Cancels current download.
    func cancelDownloading() async {
        guard let job = job else {
            return
        }
        await job.cancel()
        self.job = nil
    }
    
    /// Removes the downloaded offline map (mmpk) from disk.
    func removeDownloadedContent() {
        result = nil
        try? FileManager.default.removeItem(at: mmpkDirectory)
    }
}

private extension FileManager {
    /// Creates a temporary directory and returns the URL of the created directory.
    static func createTemporaryDirectory() -> URL {
        // swiftlint:disable:next force_try
        try! FileManager.default.url(
            for: .itemReplacementDirectory,
            in: .userDomainMask,
            appropriateFor: Bundle.main.bundleURL,
            create: true
        )
    }
}
