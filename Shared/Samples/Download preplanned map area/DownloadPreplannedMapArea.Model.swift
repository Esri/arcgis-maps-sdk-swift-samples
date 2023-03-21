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
        /// A Boolean value indicating whether to show an alert for an error.
        //@Published var isShowingErrorAlert = false
        
        /// The error shown in the alert.
        @Published var error: Error? //{
//            didSet { isShowingErrorAlert = error != nil }
        //}
        
        //@Published private(set) var preplannedMapAreas: [PreplannedMapArea] = []
        
        /// The currently selected map.
        @Published var selectedMap: SelectedMap = .onlineWebMap {
            didSet {
                selectedMapDidChange()
            }
        }
        
        /// Manages the lifetime of async tasks.
        //private var tasks = TaskManager()
        
        /// The download preplanned offline map job for each preplanned map area.
        @Published private var currentJobs: [ObjectIdentifier: DownloadPreplannedOfflineMapJob] = [:]
        
        /// The downloaded mobile map packages from the preplanned map area.
        @Published private(set) var localMapPackages: [MobileMapPackage] = []
        
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
        
        init() {
            // Create temp dsirectory.
            temporaryDirectory = FileManager.createTemporaryDirectory()
            
            // Initializes the online map and offline map task.
            onlineMap = Map(item: napervillePortalItem)
            offlineMapTask = OfflineMapTask(portalItem: napervillePortalItem)
            
            // Get the preplanned map areas and map those to offline map infos.
            Task { [weak self, offlineMapTask] in
                self?.offlineMapModels = await Result {
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
        }
        
        deinit {
            // Removes the temporary directory.
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        
        /// Updates the displayed map based on the given preplanned map area. If the preplanned map
        /// area is not nil, the preplanned map area will be downloaded if necessary and updates the map
        /// to the currently selected preplanned map area. If the preplanned map area is nil, then the map
        /// is set to the online web map.
        private func selectedMapDidChange() {
            switch selectedMap {
            case .onlineWebMap:
                offlineMap = nil
            case .offlineMap(let info):
                if info.canDownload {
                    // If we have not yet downloaded or started downloading, then kick off a
                    // download and reset selection to online map since we have to download
                    // the offline map.
                    selectedMap = .onlineWebMap
                    Task {
                        await info.download()
                    }
                } else if case .success(let mmpk) = info.result {
                    // If we have already downloaded, then open the map in the mmpk.
                    offlineMap = mmpk.maps.first
                } else {
                    // If we have a failure, then keep the online map selected.
                    selectedMap = .onlineWebMap
                }
            }
        }
        
        /// Cancels all current jobs.
        func cancelAllJobs() async {
            await withTaskGroup(of: Void.self) { group in
                currentJobs.values.forEach { job in
                    group.addTask {
                        await job.cancel()
                    }
                }
            }
        }
        
        // Removes all downloaded maps.
        func removeDownloadedMaps() {
            Task {
                // Cancels and removes all current jobs.
                await cancelAllJobs()
                currentJobs.removeAll()
                
                // Removes all downloaded map packages.
                localMapPackages.forEach { package in
                    do {
                        try FileManager.default.removeItem(at: package.fileURL)
                    } catch {
                        self.error = error
                    }
                }
                localMapPackages.removeAll()
            }
            // Sets the current map to the online web map.
            selectedMap = .onlineWebMap
        }
    }
}

class OfflineMapModel: ObservableObject {
    let preplannedMapArea: PreplannedMapArea
    let offlineMapTask: OfflineMapTask
    let temporaryDirectory: URL
    @Published var job: DownloadPreplannedOfflineMapJob?
    @Published var result: Result<MobileMapPackage, Error>?
    
    init(preplannedMapArea: PreplannedMapArea, offlineMapTask: OfflineMapTask, temporaryDirectory: URL) {
        self.preplannedMapArea = preplannedMapArea
        self.offlineMapTask = offlineMapTask
        self.temporaryDirectory = temporaryDirectory
    }
}

extension OfflineMapModel: Identifiable {}

extension OfflineMapModel: Hashable {
    static func == (lhs: OfflineMapModel, rhs: OfflineMapModel) -> Bool {
        lhs === rhs
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

@MainActor
extension OfflineMapModel {
    /// The directory that should hold the mmpk of the offline map.
    var mmpkDirectory: URL {
        temporaryDirectory
            .appendingPathComponent(preplannedMapArea.portalItem.id.rawValue)
            .appendingPathExtension("mmpk")
    }
    
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
    
    /// Whether or not the offline map can be downloaded.
    /// This returns `false` if the map was already downloaded or is in the process
    /// of being downloaded.
    var canDownload: Bool {
        job == nil && result == nil
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

//private class TaskManager {
//    private var tasks: [UUID: Task<Void, Never>] = [:]
//
//    func enqueue(_ operation: @escaping () async -> Void) {
//        let id = UUID()
//        let task = Task { [weak self] in
//            await operation()
//            self?.cleanupTask(withID: id)
//        }
//        tasks[id] = task
//    }
//
//    func cleanupTask(withID id: UUID) {
//        tasks[id] = nil
//    }
//
//    deinit {
//        // Cancels any enqueued tasks that aren't complete.
//        tasks.values.forEach { $0.cancel() }
//    }
//}

extension DownloadPreplannedMapAreaView.Model {
    enum SelectedMap: Hashable {
        case onlineWebMap
        case offlineMap(OfflineMapModel)
    }
}
