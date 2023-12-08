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

struct GenerateOfflineMapView: View {
    /// A Boolean value indicating whether the job is generating an offline map.
    @State private var isGeneratingOfflineMap = false
    
    /// A Boolean value indicating whether the job is cancelling.
    @State private var isCancellingJob = false
    
    /// The view model for this sample.
    @StateObject private var model = Model()
    
    var body: some View {
        GeometryReader { geometry in
            MapViewReader { mapView in
                MapView(map: model.offlineMap ?? model.onlineMap)
                    .interactionModes(isGeneratingOfflineMap ? [] : [.pan, .zoom])
                    .errorAlert(presentingError: $model.error)
                    .task {
                        await model.initializeOfflineMapTask()
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
                                    // Ensures cancelling the job is true.
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
                        if model.offlineMap != nil {
                            Text("Offline map generated.")
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(8)
                                .background(.thinMaterial, ignoresSafeAreaEdges: .horizontal)
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .bottomBar) {
                            Button("Generate Offline Map") {
                                isGeneratingOfflineMap = true
                            }
                            .disabled(model.isGenerateDisabled || isGeneratingOfflineMap)
                            .task(id: isGeneratingOfflineMap) {
                                // Ensures generating an offline map is true.
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
                                
                                // Generates an offline map.
                                await model.generateOfflineMap(extent: extent)
                                
                                // Sets generating an offline map to false.
                                isGeneratingOfflineMap = false
                            }
                        }
                    }
            }
        }
    }
}

private extension GenerateOfflineMapView {
    /// The model used to store the geo model and other expensive objects
    /// used in this view.
    @MainActor
    class Model: ObservableObject {
        /// The offline map that is generated.
        @Published var offlineMap: Map!
        
        /// A Boolean value indicating whether the generate button is disabled.
        @Published var isGenerateDisabled = true
        
        /// The error shown in the error alert.
        @Published var error: Error?
        
        /// The generate offline map job.
        @Published var generateOfflineMapJob: GenerateOfflineMapJob!
        
        /// The offline map task.
        private var offlineMapTask: OfflineMapTask!
        
        /// A URL to a temporary directory where the offline map files are stored.
        private let temporaryDirectory = createTemporaryDirectory()
        
        /// A portal item displaying the Naperville, IL water network.
        private let napervillePortalItem = PortalItem(
            portal: .arcGISOnline(connection: .anonymous),
            id: PortalItem.ID("acc027394bc84c2fb04d1ed317aac674")!
        )
        
        /// The online map that is loaded from a portal item.
        let onlineMap: Map
        
        init() {
            // Initializes the online map.
            onlineMap = Map(item: napervillePortalItem)
        }
        
        deinit {
            // Removes the temporary directory.
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        
        /// Initializes the offline map task.
        func initializeOfflineMapTask() async {
            do {
                // Waits for the online map to load.
                try await onlineMap.load()
                offlineMapTask = OfflineMapTask(onlineMap: onlineMap)
                isGenerateDisabled = false
            } catch {
                self.error = error
            }
        }
        
        /// Creates the generate offline map parameters.
        /// - Parameter areaOfInterest: The area of interest to create the parameters for.
        /// - Returns: A `GenerateOfflineMapParameters` if there are no errors. Otherwise, it returns `nil`,
        private func makeGenerateOfflineMapParameters(areaOfInterest: Envelope) async -> GenerateOfflineMapParameters? {
            do {
                // Returns the default parameters for the offline map task.
                return try await offlineMapTask.makeDefaultGenerateOfflineMapParameters(areaOfInterest: areaOfInterest)
            } catch {
                self.error = error
                return nil
            }
        }
        
        /// Generates the offline map.
        /// - Parameter extent: The area of interest's envelope to generate an offline map for.
        func generateOfflineMap(extent: Envelope) async {
            // Disables the generate offline map button.
            isGenerateDisabled = true
            
            // Creates the default parameters for the offline map task.
            guard let parameters = await makeGenerateOfflineMapParameters(areaOfInterest: extent) else {
                isGenerateDisabled = false
                return
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
            
            do {
                // Awaits the output of the job.
                let output = try await generateOfflineMapJob.output
                // Sets the offline map to the output's offline map.
                offlineMap = output.offlineMap
                // Sets the initial viewpoint of the offline map.
                offlineMap.initialViewpoint = Viewpoint(boundingGeometry: extent.expanded(by: 0.8))
            } catch {
                // Shows an alert with the error if the job fails.
                self.error = error
            }
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
    func expanded(by factor: Double) -> Envelope {
        let builder = EnvelopeBuilder(envelope: self)
        builder.expand(by: factor)
        return builder.toGeometry()
    }
}

#Preview {
    NavigationView {
        GenerateOfflineMapView()
    }
}
