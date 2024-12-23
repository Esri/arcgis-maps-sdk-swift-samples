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

struct GenerateOfflineMapWithLocalBasemapView: View {
    /// A Boolean value indicating whether the job is generating an offline map.
    @State private var isGeneratingOfflineMap = false
    
    /// A Boolean value indicating when the basemap choice dialog is presented.
    @State private var basemapChoiceIsPresented = false
    
    /// A Boolean value indicating whether the job is cancelling.
    @State private var isCancellingJob = false
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    /// The title to show in the confirmation dialog.
    private let basemapChoiceTitle: String = {
        let displayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as! String
        return String(format: "“%@” has a local imagery basemap that can be used in the map. Would you like to use the local or the online basemap?", displayName)
    }()
    
    /// The view model for this sample.
    @StateObject private var model = Model()
    
    var body: some View {
        GeometryReader { geometry in
            MapViewReader { mapView in
                MapView(map: model.offlineMap ?? model.onlineMap)
                    .interactionModes(isGeneratingOfflineMap ? [] : [.pan, .zoom])
                    .errorAlert(presentingError: $error)
                    .task {
                        do {
                            try await model.initializeOfflineMapTask()
                        } catch {
                            self.error = error
                        }
                    }
                    .onDisappear {
                        Task { await model.cancelJob() }
                    }
                    .overlay {
                        Rectangle()
                            .stroke(.red, lineWidth: 2)
                            .padding(EdgeInsets(top: 20, leading: 20, bottom: 44, trailing: 20))
                            .opacity(model.offlineMap == nil ? 1 : 0)
                    }
                    .overlay {
                        if isGeneratingOfflineMap,
                           let progress = model.generateOfflineMapJob?.progress {
                            VStack(spacing: 16) {
                                ProgressView(progress)
                                    .progressViewStyle(.linear)
                                    .frame(maxWidth: 200)
                                
                                Button("Cancel") {
                                    isCancellingJob = true
                                }
                                .disabled(isCancellingJob)
                                .task(id: isCancellingJob) {
                                    guard isCancellingJob else { return }
                                    // Cancels the job.
                                    await model.cancelJob()
                                    // Sets cancelling the job and generating an
                                    // offline map to false.
                                    isCancellingJob = false
                                    isGeneratingOfflineMap = false
                                }
                            }
                            .padding()
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                            .shadow(radius: 3)
                        }
                    }
                    .overlay(alignment: .top) {
                        Text("Offline map generated.")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(8)
                            .background(.thinMaterial, ignoresSafeAreaEdges: .horizontal)
                            .opacity(model.offlineMap != nil ? 1 : 0)
                    }
                    .toolbar {
                        ToolbarItem(placement: .bottomBar) {
                            Button("Generate Offline Map") {
                                if model.canUseLocalBasemap {
                                    basemapChoiceIsPresented = true
                                } else {
                                    isGeneratingOfflineMap = true
                                }
                            }
                            .disabled(model.isGenerateDisabled || isGeneratingOfflineMap)
                            .confirmationDialog(
                                basemapChoiceTitle,
                                isPresented: $basemapChoiceIsPresented,
                                titleVisibility: .visible
                            ) {
                                Button("Use Local Basemap") {
                                    model.usesLocalBasemap = true
                                    isGeneratingOfflineMap = true
                                }
                                Button("Use Online Basemap") {
                                    model.usesLocalBasemap = false
                                    isGeneratingOfflineMap = true
                                }
                            }
                            .task(id: isGeneratingOfflineMap) {
                                guard isGeneratingOfflineMap else { return }
                                
                                // Creates a rectangle from the area of interest.
                                let viewRect = geometry.frame(in: .local).inset(
                                    by: UIEdgeInsets(
                                        top: 20,
                                        left: geometry.safeAreaInsets.leading + 20,
                                        bottom: 44,
                                        right: -geometry.safeAreaInsets.trailing + 20
                                    )
                                )
                                
                                // Creates an envelope from the rectangle.
                                guard let extent = mapView.envelope(fromViewRect: viewRect) else { return }
                                
                                do {
                                    // Generates an offline map.
                                    try await model.generateOfflineMap(extent: extent)
                                } catch {
                                    self.error = error
                                }
                                
                                // Sets generating an offline map to false.
                                isGeneratingOfflineMap = false
                            }
                        }
                    }
            }
        }
    }
}

private extension GenerateOfflineMapWithLocalBasemapView {
    /// The model used to store the geo model and other expensive objects
    /// used in this view.
    @MainActor
    class Model: ObservableObject {
        /// The offline map that is generated.
        @Published private(set) var offlineMap: Map!
        
        /// A Boolean value indicating whether the generate button is disabled.
        @Published private(set) var isGenerateDisabled = true
        
        /// A Boolean value indicating if the local basemap is available to be used.
        let canUseLocalBasemap = FileManager.default.fileExists(atPath: URL.napervilleImageryBasemap.path())
        
        /// A Boolean value indicating whether the offline map uses the local or online basemap.
        var usesLocalBasemap = false
        
        /// The generate offline map job.
        @Published private(set) var generateOfflineMapJob: GenerateOfflineMapJob!
        
        /// The offline map task.
        private var offlineMapTask: OfflineMapTask!
        
        /// A URL to a temporary directory where the offline map files are stored.
        private let temporaryDirectory = createTemporaryDirectory()
        
        /// The online map that is loaded from a portal item.
        let onlineMap: Map = {
            // A portal item displaying the Naperville, IL water network.
            let napervillePortalItem = PortalItem(
                portal: .arcGISOnline(connection: .anonymous),
                id: .napervilleWaterNetwork
            )
            
            // Creates map with portal item.
            let map = Map(item: napervillePortalItem)
            
            // Sets the min scale to avoid requesting a huge download.
            map.minScale = 1e4
            
            return map
        }()
        
        deinit {
            // Removes the temporary directory.
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        
        /// Initializes the offline map task.
        func initializeOfflineMapTask() async throws {
            // Waits for the online map to load.
            try await onlineMap.load()
            offlineMapTask = OfflineMapTask(onlineMap: onlineMap)
            isGenerateDisabled = false
        }
        
        /// Creates the generate offline map parameters.
        /// - Parameter areaOfInterest: The area of interest to create the parameters for.
        /// - Returns: A `GenerateOfflineMapParameters` if there are no errors.
        private func makeGenerateOfflineMapParameters(areaOfInterest: Envelope) async throws -> GenerateOfflineMapParameters {
            // Returns the default parameters for the offline map task.
            return try await offlineMapTask.makeDefaultGenerateOfflineMapParameters(areaOfInterest: areaOfInterest)
        }
        
        /// Generates the offline map.
        /// - Parameter extent: The area of interest's envelope to generate an offline map for.
        func generateOfflineMap(extent: Envelope) async throws {
            // Disables the generate offline map button.
            isGenerateDisabled = true
            
            // Creates the default parameters for the offline map task.
            let parameters = try await makeGenerateOfflineMapParameters(areaOfInterest: extent)
            parameters.includesBasemap = true
            if canUseLocalBasemap && usesLocalBasemap {
                parameters.referenceBasemapDirectoryURL = .napervilleImageryBasemap.deletingLastPathComponent()
                parameters.referenceBasemapFilename = URL.napervilleImageryBasemap.lastPathComponent
            }
            
            // Creates the generate offline map job based on the parameters.
            generateOfflineMapJob = offlineMapTask.makeGenerateOfflineMapJob(
                parameters: parameters,
                downloadDirectory: temporaryDirectory
            )
            
            // Starts the job.
            generateOfflineMapJob.start()
            
            defer {
                generateOfflineMapJob = nil
                isGenerateDisabled = offlineMap != nil
            }
            
            // Awaits the output of the job.
            let output = try await generateOfflineMapJob.output
            // Sets the offline map to the output's offline map.
            offlineMap = output.offlineMap
            // Sets the initial viewpoint of the offline map.
            offlineMap.initialViewpoint = Viewpoint(boundingGeometry: extent.expanded(by: 0.8))
        }
        
        /// Cancels the generate offline map job.
        func cancelJob() async {
            // Cancels the generate offline map job.
            await generateOfflineMapJob?.cancel()
            generateOfflineMapJob = nil
        }
        
        /// Creates a temporary directory.
        private static func createTemporaryDirectory() -> URL {
            // swiftlint:disable:next force_try
            try! FileManager.default.url(
                for: .itemReplacementDirectory,
                in: .userDomainMask,
                appropriateFor: FileManager.default.temporaryDirectory,
                create: true
            )
        }
    }
}

private extension Envelope {
    /// Expands the envelope by a given factor.
    /// - Parameter factor: The amount to expand the envelope by.
    /// - Returns: An envelope expanded by the specified factor.
    func expanded(by factor: Double) -> Envelope {
        let builder = EnvelopeBuilder(envelope: self)
        builder.expand(by: factor)
        return builder.toGeometry()
    }
}

private extension URL {
    /// A URL to the local Naperville imagery basemap.
    static var napervilleImageryBasemap: URL {
        Bundle.main.url(forResource: "naperville_imagery", withExtension: "tpkx")!
    }
}

private extension PortalItem.ID {
    /// The portal item ID of the Naperville water network web map to be displayed on the map.
    static var napervilleWaterNetwork: Self { Self("acc027394bc84c2fb04d1ed317aac674")! }
}
