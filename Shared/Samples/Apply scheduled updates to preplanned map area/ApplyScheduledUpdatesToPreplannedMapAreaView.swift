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
import SwiftUI

struct ApplyScheduledUpdatesToPreplannedMapAreaView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// A Boolean value indicating whether the alert for
    /// scheduled updates is presented.
    @State private var updatesAlertIsPresented = false
    
    /// A Boolean value indicating whether the alert for
    /// no available updates is presented.
    @State private var noUpdatesAlertIsPresented = false
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    var body: some View {
        MapView(map: model.map)
            .errorAlert(presentingError: $error)
            .task {
                do {
                    try await model.setUp()
                } catch {
                    self.error = error
                }
            }
            .onChange(of: model.updatesInfo == nil) {
                guard let updatesInfo = model.updatesInfo else { return }
                // Handle the updates info from the offline map sync task.
                handleUpdatesInfo(updatesInfo)
            }
            .overlay {
                // Show a progress view for the offline map sync job that downloads
                // the available updates.
                if let progress = model.offlineMapSyncJob?.progress {
                    VStack(spacing: 16) {
                        ProgressView(progress)
                            .progressViewStyle(.linear)
                            .frame(maxWidth: 200)
                    }
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    .shadow(radius: 3)
                }
            }
            .alert("Scheduled Updates Available", isPresented: $updatesAlertIsPresented) {
                Button("Cancel", role: .cancel) {}
                Button("Apply") {
                    Task {
                        do {
                            try await model.applyScheduledUpdates()
                        } catch {
                            self.error = error
                        }
                    }
                }
            } message: {
                // Get the download size for the update.
                let downloadSizeString = ByteCountFormatter.string(
                    from: Measurement(
                        value: Double(model.updatesInfo?.scheduledUpdatesDownloadSize ?? .zero),
                        unit: .bytes
                    ),
                    countStyle: .file
                )
                Text("A \(downloadSizeString) update is available. Would you like to apply it?")
            }
            .alert("Scheduled Updates Unavailable", isPresented: $noUpdatesAlertIsPresented) {
            } message: {
                Text("There are no updates available.")
            }
    }
    
    /// Displays different alerts based on the offline map updates info.
    /// - Parameter info: The updates info from the offline map sync task.
    private func handleUpdatesInfo(_ info: OfflineMapUpdatesInfo) {
        switch info.downloadAvailability {
        case .available:
            updatesAlertIsPresented = true
        case .noneAvailable, .indeterminate:
            noUpdatesAlertIsPresented = true
        @unknown default:
            fatalError("Unknown offline map updates info")
        }
    }
}

private extension ApplyScheduledUpdatesToPreplannedMapAreaView {
    /// The model used to store the geo model and other expensive objects
    /// used in this view.
    @MainActor
    class Model: ObservableObject {
        /// A map from the mobile map package.
        @Published private(set) var map = Map()
        
        /// The sync job used to apply updates to the offline map.
        @Published private(set) var offlineMapSyncJob: OfflineMapSyncJob?
        
        /// The information on the available updates for an offline map.
        @Published private(set) var updatesInfo: OfflineMapUpdatesInfo?
        
        /// The temporary URL to store the mobile map package.
        private let temporaryMobileMapPackageURL = FileManager
            .createTemporaryDirectory()
            .appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString)
        
        /// The mobile map package used by this sample.
        private var mobileMapPackage: MobileMapPackage?
        
        /// The sync task used to check for scheduled updates.
        private var offlineMapSyncTask: OfflineMapSyncTask?
        
        /// Loads the offline map and sets up the sync task.
        func setUp() async throws {
            // Open and load the mobile map package from local disk.
            let mobileMapPackageURL = Bundle.main.url(forResource: "canyonlands", withExtension: nil)!
            // Copy the map package from the bundle so updates can be applied.
            try FileManager.default.copyItem(
                at: mobileMapPackageURL,
                to: temporaryMobileMapPackageURL
            )
            let mobileMapPackage = MobileMapPackage(fileURL: temporaryMobileMapPackageURL)
            try await mobileMapPackage.load()
            self.mobileMapPackage = mobileMapPackage
            
            // Create a sync task from the first map of the map package.
            map = mobileMapPackage.maps.first!
            let offlineMapSyncTask = OfflineMapSyncTask(map: map)
            self.offlineMapSyncTask = offlineMapSyncTask
            
            // Get high-level information on the available updates.
            updatesInfo = try await offlineMapSyncTask.checkForUpdates()
        }
        
        /// Applies available updates to the offline map.
        func applyScheduledUpdates() async throws {
            guard let mobileMapPackage, let offlineMapSyncTask else { return }
            
            // Create default parameters and the sync job from the sync task.
            let parameters = try await offlineMapSyncTask.makeDefaultOfflineMapSyncParameters()
            let offlineMapSyncJob = offlineMapSyncTask.makeSyncOfflineMapJob(parameters: parameters)
            self.offlineMapSyncJob = offlineMapSyncJob
            
            // Start the job.
            offlineMapSyncJob.start()
            // Await the output of the job and assigns the result.
            let output = try await offlineMapSyncJob.output
            // Set the job to nil to release the reference.
            self.offlineMapSyncJob = nil
            
            // Return if no reopen is required to see the updated map package.
            guard output.mobileMapPackageReopenIsRequired else { return }
            
            // Close then reload the updated map package.
            mobileMapPackage.close()
            let updatedMobileMapPackage = MobileMapPackage(fileURL: temporaryMobileMapPackageURL)
            try await updatedMobileMapPackage.load()
            map = updatedMobileMapPackage.maps.first!
            self.mobileMapPackage = updatedMobileMapPackage
        }
        
        deinit {
            // Remove the temporary directory.
            let temporaryDirectory = temporaryMobileMapPackageURL.deletingLastPathComponent()
            try? FileManager.default.removeItem(at: temporaryDirectory)
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
