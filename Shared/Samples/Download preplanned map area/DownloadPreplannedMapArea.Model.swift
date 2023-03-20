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
        enum SelectedMap { // swiftlint:disable:this nesting
            case onlineWebMap
            case preplannedMap(area: PreplannedMapArea)
        }
        
        /// A Boolean value indicating whether to show an alert for an error.
        @Published var isShowingErrorAlert = false
        
        /// The error shown in the alert.
        @Published var error: Error? {
            didSet { isShowingErrorAlert = error != nil }
        }
        
        /// The preplanned map areas from the offline map task.
        @Published private(set) var preplannedMapAreas: [PreplannedMapArea] = []
        
        /// The currently selected map.
        @Published var selectedMap: SelectedMap = .onlineWebMap {
            didSet {
                Task {
                    await selectedMapDidChange()
                }
            }
        }
        
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
        private let temporaryDirectoryURL = makeTemporaryDirectory()
        
        init() {
            // Initializes the online map and offline map task.
            onlineMap = Map(item: napervillePortalItem)
            offlineMapTask = OfflineMapTask(portalItem: napervillePortalItem)
        }
        
        deinit {
            // Removes the temporary directory.
            try? FileManager.default.removeItem(at: temporaryDirectoryURL)
        }
        
        /// Loads each preplanned map area from the offline map
        func loadPreplannedMapAreas() async {
            // Ensures that the preplanned map areas do not already exist.
            guard preplannedMapAreas.isEmpty else { return }
            do {
                // Sorts the offline map task's preplanned map areas alphabetically.
                preplannedMapAreas = try await offlineMapTask.preplannedMapAreas.sorted(
                    using: KeyPathComparator(\.portalItem.title)
                )
                
                // Loads the preplanned map areas.
                try await preplannedMapAreas.load()
            } catch {
                self.error = error
            }
        }
        
        /// Updates the displayed map based on the given preplanned map area. If the preplanned map
        /// area is not nil, the preplanned map area will be downloaded if necessary and updates the map
        /// to the currently selected preplanned map area. If the preplanned map area is nil, then the map
        /// is set to the online web map.
        private func selectedMapDidChange() async {
            switch selectedMap {
            case .onlineWebMap:
                offlineMap = nil
            case .preplannedMap(let preplannedMapArea) where preplannedMapArea.loadStatus == .loaded:
                // Downloads the preplanned map area if it has not been downloaded.
                await downloadPreplannedMapArea(preplannedMapArea)
                
                // Updates the offline map if the currently selected map is not an online map.
                if case .preplannedMap(let currentlySelectedArea) = selectedMap {
                    offlineMap = localMapPackages
                        .first(where: { $0.fileURL.path.contains(currentlySelectedArea.portalItemIdentifier) })?
                        .maps.first
                }
            default:
                break
            }
        }
        
        /// Creates the parameters for a download preplanned offline map job.
        /// - Parameter preplannedMapArea: The preplanned map area to create parameters for.
        /// - Returns: A `DownloadPreplannedOfflineMapParameters` if there are no errors.
        private func makeDownloadPreplannedOfflineMapParameters(
            preplannedMapArea: PreplannedMapArea
        ) async throws -> DownloadPreplannedOfflineMapParameters {
            // Creates the default parameters.
            let parameters = try await offlineMapTask.makeDefaultDownloadPreplannedOfflineMapParameters(
                preplannedMapArea: preplannedMapArea
            )
            // Sets the update mode to no updates as the offline map is display-only.
            parameters.updateMode = .noUpdates
            return parameters
        }
        
        /// Downloads the given preplanned map area.
        /// - Parameter preplannedMapArea: The preplanned map area to be downloaded.
        private func downloadPreplannedMapArea(_ preplannedMapArea: PreplannedMapArea) async {
            // Ensures the preplanned map area has not been downloaded.
            guard job(for: preplannedMapArea) == nil else { return }
            do {
                // Creates the parameters for the download preplanned offline map job.
                let parameters = try await makeDownloadPreplannedOfflineMapParameters(preplannedMapArea: preplannedMapArea)
                
                // Creates the download directory URL based on the preplanned map area's
                // portal item identifier.
                let downloadDirectoryURL = temporaryDirectoryURL
                    .appendingPathComponent(preplannedMapArea.portalItemIdentifier)
                    .appendingPathExtension("mmpk")
                
                // Creates the download preplanned offline map job.
                let job = offlineMapTask.makeDownloadPreplannedOfflineMapJob(
                    parameters: parameters,
                    downloadDirectory: downloadDirectoryURL
                )
                
                // Adds the job for the preplanned map area to the current jobs.
                currentJobs[ObjectIdentifier(preplannedMapArea)] = job
                
                // Starts the job.
                job.start()
                
                // Awaits the output of the job.
                let output = try await job.output
                // Adds the output's mobile map package to the downloaded map packages.
                localMapPackages.append(output.mobileMapPackage)
            } catch is CancellationError {
                // Does nothing if the error is a cancellation error.
            } catch {
                // Shows an alert if any errors occur.
                self.error = error
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
        
        /// Gets the job for the given preplanned map area from the current jobs.
        /// - Parameter preplannedMapArea: The preplanned map area to get the job from.
        /// - Returns: A `DownloadPreplannedOfflineMapJob` from the current jobs.
        func job(for preplannedMapArea: PreplannedMapArea) -> DownloadPreplannedOfflineMapJob? {
            currentJobs[ObjectIdentifier(preplannedMapArea)]
        }
        
        /// Creates a temporary directory.
        private static func makeTemporaryDirectory() -> URL {
            // swiftlint:disable:next force_try
            try! FileManager.default.url(
                for: .itemReplacementDirectory,
                in: .userDomainMask,
                appropriateFor: Bundle.main.bundleURL,
                create: true
            )
        }
    }
}

extension DownloadPreplannedMapAreaView.Model.SelectedMap: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.onlineWebMap, .onlineWebMap): return true
        case (let .preplannedMap(lhsArea), let .preplannedMap(rhsArea)):
            return lhsArea.portalItem.id == rhsArea.portalItem.id
        default:
            return false
        }
    }
}

extension DownloadPreplannedMapAreaView.Model.SelectedMap: Hashable {
    func hash(into hasher: inout Hasher) {
        switch self {
        case .onlineWebMap:
            break
        case .preplannedMap(let area):
            hasher.combine(area.portalItem.id)
        }
    }
}

private extension PreplannedMapArea {
    /// The portal item's ID.
    var portalItemIdentifier: String { portalItem.id.rawValue }
}
