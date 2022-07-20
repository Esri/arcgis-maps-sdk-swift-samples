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

struct DownloadPreplannedMapAreaView: View {
    /// A Boolean value indicating whether to select a map.
    @State private var isSelectingMap = false
    
    /// A Boolean value indicating whether to show delete alert.
    @State private var isShowingDeleteAlert = false
    
    /// A Boolean value indicating whether to show an alert for an error.
    @State private var isShowingErrorAlert = false
    
    /// The view model for this sample.
    @StateObject private var model = Model()
    
    var body: some View {
        MapView(map: model.map)
            .alert(isPresented: $isShowingErrorAlert, presentingError: model.error)
            .onReceive(model.$error) { error in
                if error != nil {
                    isShowingErrorAlert = true
                }
            }
            .alert("Delete all offline areas", isPresented: $isShowingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    Task { await model.removeDownloadedMaps() }
                }
            } message: {
                Text("Are you sure you want to delete all preplanned map areas?")
            }
            .overlay(alignment: .top) {
                Text("Current map: \(model.map.item?.title ?? "Unknown")")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(.thinMaterial, ignoresSafeAreaEdges: .horizontal)
            }
            .task {
                await model.loadPreplannedMapAreas()
            }
            .onDisappear {
                Task { await model.cancelAllJobs() }
            }
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Spacer()
                    Button("Select Map") {
                        isSelectingMap.toggle()
                    }
                    .sheet(isPresented: $isSelectingMap, detents: [.medium]) {
                        NavigationView {
                            List {
                                Section {
                                    Picker("Web Maps (Online)", selection: $model.currentPreplannedMapArea) {
                                        Text("Web Map (Online)")
                                            .tag(nil as PreplannedMapArea?)
                                    }
                                    .labelsHidden()
                                    .pickerStyle(.inline)
                                }
                                
                                Section {
                                    Picker("Preplanned Map Areas", selection: $model.currentPreplannedMapArea) {
                                        ForEach(model.preplannedMapAreas, id: \.portalItemIdentifier) { preplannedMapArea in
                                            HStack {
                                                if let job = model.currentJobs[preplannedMapArea] {
                                                    ProgressView(job.progress)
                                                        .progressViewStyle(Gauge())
                                                        .fixedSize()
                                                }
                                                Text(preplannedMapArea.displayName)
                                                Spacer()
                                            }
                                            .tag(Optional(preplannedMapArea))
                                        }
                                    }
                                    .labelsHidden()
                                    .pickerStyle(.inline)
                                } header: {
                                    Text("Preplanned Map Areas")
                                } footer: {
                                    Text(footerText)
                                }
                            }
                            .task(id: model.currentPreplannedMapArea) {
                                await model.handlePreplannedMapSelection(for: model.currentPreplannedMapArea)
                            }
                            .navigationTitle("Select Map")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button("Done") { isSelectingMap = false }
                                }
                            }
                        }
                        .navigationViewStyle(.stack)
                    }
                    Spacer()
                    Button {
                        isShowingDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(model.isDeleteDisabled)
                }
            }
    }
}

private extension DownloadPreplannedMapAreaView {
    /// A view model for this sample.
    @MainActor
    class Model: ObservableObject {
        /// The error shown in the alert.
        @Published var error: Error?
        
        /// The preplanned map areas from the offline map task.
        @Published var preplannedMapAreas: [PreplannedMapArea] = []
        
        /// The currently selected preplanned map area. Is nil if viewing the web map.
        @Published var currentPreplannedMapArea: PreplannedMapArea?
        
        /// The download preplanned offline map job for each preplanned map area.
        @Published var currentJobs: [PreplannedMapArea: DownloadPreplannedOfflineMapJob] = [:]
        
        /// The map used in the map view.
        @Published var map: Map
        
        /// The downloaded mobile map packages from the preplanned map area.
        @Published private var localMapPackages: [MobileMapPackage] = []
        
        /// A Boolean value indicating whether the delete button is disabled.
        var isDeleteDisabled: Bool { localMapPackages.isEmpty }
        
        /// The online map of the Naperville water network.
        private let onlineMap = Map(item: PortalItem.napervilleWaterNetwork)
        
        /// The offline map task.
        private let offlineMapTask = OfflineMapTask(portalItem: .napervilleWaterNetwork)
        
        /// A URL to a temporary directory where the downloaded map packages are stored.
        private let temporaryDirectoryURL = FileManager
            .default
            .temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        
        init() {
            // Sets the map to the online map.
            map = onlineMap
            // Creates the temporary directory.
            makeTemporaryDirectory()
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
                preplannedMapAreas = try await offlineMapTask.preplannedMapAreas.sorted { $0.displayName < $1.displayName }
                
                // Loads the preplanned map areas.
                await withThrowingTaskGroup(of: Void.self) { group in
                    preplannedMapAreas.forEach { preplannedMapArea in
                        group.addTask {
                            try await preplannedMapArea.load()
                        }
                    }
                }
            } catch {
                self.error = error
            }
        }
        
        /// Updates the displayed map based on the given preplanned map area. If the preplanned map
        /// area is not nil, the preplanned map area will be downloaded if necessary and updates the map
        /// to the currently selected preplanned map area. If the preplanned map area is nil, then the map
        /// is set to the online web map.
        /// - Parameter preplannedMapArea: The preplanned map area used to change the displayed map.
        func handlePreplannedMapSelection(for preplannedMapArea: PreplannedMapArea?) async {
            if let preplannedMapArea = preplannedMapArea {
                // Ensures the map is loaded.
                guard preplannedMapArea.loadStatus == .loaded else { return }
                
                // Downloads the preplanned map area if it has not been downloaded.
                if currentJobs[preplannedMapArea] == nil {
                    await downloadPreplannedMapArea(preplannedMapArea)
                }
                
                // Sets the displayed map to the selected preplanned map area.
                if let currentPreplannedMapArea = currentPreplannedMapArea,
                   // Gets the downloaded map package for the selected preplanned map area.
                   let mapPackage = localMapPackages.first(where: { $0.fileURL.path.contains(currentPreplannedMapArea.portalItemIdentifier) }),
                   let offlineMap = mapPackage.maps.first {
                    // Sets the map to the offline map.
                    map = offlineMap
                }
            } else {
                // Sets the map to the online map if the given preplanned map
                // area is nil.
                map = onlineMap
            }
        }
        
        /// Downloads the given preplanned map area.
        /// - Parameter preplannedMapArea: The preplanned map area to be downloaded.
        private func downloadPreplannedMapArea(_ preplannedMapArea: PreplannedMapArea) async {
            do {
                // Creates the default parameters.
                let parameters = try await offlineMapTask.makeDefaultDownloadPreplannedOfflineMapParameters(
                    preplannedMapArea: preplannedMapArea
                )
                // Sets the update mode to no updates as the offline map is display-only.
                parameters.updateMode = .noUpdates
                
                // Creates the download directory URL based on the preplanned
                // map area's portal item identifier.
                let downloadDirectoryURL = temporaryDirectoryURL
                    .appendingPathComponent(preplannedMapArea.portalItemIdentifier)
                    .appendingPathExtension("mmpk")
                
                // Creates the download preplanned offline map job.
                let job = offlineMapTask.makeDownloadPreplannedOfflineMapJob(
                    parameters: parameters,
                    downloadDirectory: downloadDirectoryURL
                )
                
                // Adds the job for the preplanned map area to the current jobs.
                currentJobs[preplannedMapArea] = job
                
                // Starts the job.
                job.start()
                
                // Awaits the results of the job.
                let result = await job.result
                
                switch result {
                case .success(let output):
                    // Adds the output's mobile map package to the downloaded map packages.
                    localMapPackages.append(output.mobileMapPackage)
                case .failure(let error):
                    // Shows an alert with the error if the job fails and the
                    // error is not a cancellation error.
                    guard !(error is CancellationError) else { return }
                    self.error = error
                }
            } catch {
                self.error = error
            }
        }
        
        /// Cancels all current jobs.
        func cancelAllJobs() async {
            await withTaskGroup(of: Void.self) { group in
                currentJobs.forEach { _, job in
                    group.addTask {
                        await job.cancel()
                    }
                }
            }
        }
        
        // Removes all downloaded maps.
        func removeDownloadedMaps() async {
            // Cancels all current jobs.
            await cancelAllJobs()
            
            // Sets the current map to the online web map.
            map = onlineMap
            currentPreplannedMapArea = nil
            
            // Removes all downloaded map packages.
            localMapPackages.forEach { package in
                do {
                    try FileManager.default.removeItem(at: package.fileURL)
                } catch {
                    self.error = error
                }
            }
            localMapPackages.removeAll()
            
            // Removes all current jobs.
            currentJobs.removeAll()
        }
        
        /// Creates the temporary directory.
        private func makeTemporaryDirectory() {
            do {
                try FileManager.default.createDirectory(at: temporaryDirectoryURL, withIntermediateDirectories: false)
            } catch {
                self.error = error
            }
        }
    }
}

private extension DownloadPreplannedMapAreaView {
    /// The text for the footer of a section.
    var footerText: String {
        """
        Tap to download a preplanned map area for offline use. Once the selected \
        map is downloaded, the map will update with the offline map's area.
        """
    }
    
    /// A circular gauge progress view  style..
    struct Gauge: ProgressViewStyle {
        func makeBody(configuration: Configuration) -> some View {
            let fractionCompleted = configuration.fractionCompleted ?? 0
            
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                Circle()
                    .trim(from: 0, to: fractionCompleted)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
    }
}

private extension PreplannedMapArea {
    /// The name of the preplanned map area.
    var displayName: String {
        portalItem?.title.replacingOccurrences(of: "_", with: " ") ?? portalItem?.name ?? "Untitled"
    }
    /// The portal item's ID.
    var portalItemIdentifier: String {
        portalItem?.id.rawValue ?? "-"
    }
}

extension PreplannedMapArea: Identifiable {}

extension PreplannedMapArea: Equatable {
    public static func == (lhs: PreplannedMapArea, rhs: PreplannedMapArea) -> Bool {
        lhs === rhs
    }
}

extension PreplannedMapArea: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

private extension PortalItem {
    /// A portal item displaying the Naperville, IL water network.
    static var napervilleWaterNetwork: Self {
        .init(
            portal: .arcGISOnline(isLoginRequired: false),
            id: PortalItem.ID("acc027394bc84c2fb04d1ed317aac674")!
        )
    }
}
