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
                    .interactionModes([.pan, .zoom])
                    .disabled(isGeneratingOfflineMap)
                    .alert(isPresented: $model.isShowingAlert, presentingError: model.error)
                    .task {
                        await model.initializeOfflineMapTask()
                    }
                    .onDisappear {
                        model.removeTemporaryDirectory()
                    }
                    .overlay {
                        if model.offlineMap == nil {
                            Rectangle()
                                .stroke(.red, lineWidth: 2)
                                .frame(width: geometry.size.width * 0.8, height: geometry.size.height * 0.8)
                        }
                        
                        // NOTE: Temporary placeholder for job progress view.
                        if isGeneratingOfflineMap {
                            VStack {
                                if let progress = model.generateOfflineMapJob?.progress {
                                    ProgressView(progress)
                                        .progressViewStyle(LinearProgressStyle())
                                }
                                
                                Button("Cancel") {
                                    isCancellingJob = true
                                }
                                .padding(.top)
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
                    .toolbar {
                        ToolbarItem(placement: .bottomBar) {
                            Button("Generate Offline Map") {
                                isGeneratingOfflineMap = true
                            }
                            .disabled(model.isGenerateDisabled || isGeneratingOfflineMap)
                            .task(id: isGeneratingOfflineMap) {
                                // Ensures generating an offline map is true.
                                guard isGeneratingOfflineMap else { return }
                                // Generates an offline map.
                                await model.generateOfflineMap(mapView: mapView, geometry: geometry)
                                // Disables the generate offline map button.
                                model.isGenerateDisabled = true
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
    /// The view model for this sample.
    @MainActor class Model: ObservableObject {
        /// The offline map that is generated.
        @Published var offlineMap: Map?
        
        /// A Boolean value indicating whether the generate button is disabled.
        @Published var isGenerateDisabled = true
        
        /// A Boolean value indicating whether to show an alert.
        @Published var isShowingAlert = false
        
        /// The error shown in the alert.
        @Published var error: Error?
        
        /// The generate offline map job.
        @Published var generateOfflineMapJob: GenerateOfflineMapJob!
        
        /// The offline map task.
        private var offlineMapTask: OfflineMapTask!
        
        /// A URL referencing the temporary directory where the offline map files are stored.
        private let temporaryDirectory = FileManager
            .default
            .temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        
        /// The online map that is loaded from a portal item.
        let onlineMap = Map(item: PortalItem.napervilleWaterNetwork)
        
        init() {
            // Creates the temporary directory.
            makeTemporaryDirectory()
        }
        
        /// Initializes the offline map task.
        func initializeOfflineMapTask() async {
            do {
                // Waits for the online map to load.
                try await onlineMap.load()
                offlineMapTask = OfflineMapTask(portalItem: .napervilleWaterNetwork)
                isGenerateDisabled = false
            } catch {
                self.error = error
                isShowingAlert = true
            }
        }
        
        /// Generates the offline map.
        /// - Parameters:
        ///   - mapView: A map view proxy used to convert the min and max screen points to the map
        ///   view's spatial reference.
        ///   - geometry: A geometry proxy used to reference the min and max screen points that
        ///   represent the area of interest.
        func generateOfflineMap(mapView: MapViewProxy, geometry: GeometryProxy) async {
            // Creates the min and max points for the envelope.
            guard let min = mapView.location(fromScreenPoint: geometry.min()),
                  let max = mapView.location(fromScreenPoint: geometry.max()) else {
                return
            }
            
            // Creates the envelope representing the area of interest.
            let extent = Envelope(min: min, max: max)
            
            do {
                // Creates the default parameters for the offline map task.
                let parameters = try await offlineMapTask.makeDefaultGenerateOfflineMapParameters(areaOfInterest: extent)
                
                // Creates the generate offline map job based on the parameters.
                generateOfflineMapJob = offlineMapTask.makeGenerateOfflineMapJob(parameters: parameters, downloadDirectory: temporaryDirectory)
                
                // Starts the job.
                generateOfflineMapJob.start()
                
                // Awaits the result of the job.
                let result = await generateOfflineMapJob.result
                
                // Sets the job to nil.
                generateOfflineMapJob = nil
                
                switch result {
                case .success(let output):
                    // Sets the offline map to the output's offline map.
                    offlineMap = output.offlineMap
                    // Sets the initial viewpoint of the offline map.
                    offlineMap?.initialViewpoint = Viewpoint(targetExtent: extent.expanded(by: 0.8))
                case .failure(let error):
                    // Shows an alert with the error if the job fails and the
                    // error is not a cancellation error.
                    guard !(error is CancellationError) else { return }
                    self.error = error
                    isShowingAlert = true
                }
            } catch {
                self.error = error
                isShowingAlert = true
            }
        }
        
        /// Cancels the generate offline map job.
        func cancelJob() async {
            // Cancels the generate offline map job.
            await generateOfflineMapJob.cancel()
            generateOfflineMapJob = nil
        }
        
        /// Creates the temporary directory.
        private func makeTemporaryDirectory() {
            do {
                try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: false)
            } catch {
                self.error = error
                isShowingAlert = true
            }
        }
        
        /// Removes the temporary directory.
        func removeTemporaryDirectory() {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
    }
}

private extension GenerateOfflineMapView {
    struct LinearProgressStyle: ProgressViewStyle {
        func makeBody(configuration: Configuration) -> some View {
            let fractionCompleted = configuration.fractionCompleted ?? 0
            
            VStack {
                Text("\(fractionCompleted, format: .percent) completed")
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray4))
                    
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.accentColor)
                        .frame(width: 200 * fractionCompleted)
                }
                .frame(maxWidth: 200, maxHeight: 8)
            }
        }
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

private extension Envelope {
    /// Expands the envelope by a given factor.
    func expanded(by factor: Double) -> Envelope {
        let builder = EnvelopeBuilder(envelope: self)
        builder.expand(factor: factor)
        return builder.toGeometry()
    }
}

private extension GeometryProxy {
    /// A `CGPoint` that has x and y coordinates at 10% the size's width and height, respectively.
    func min() -> CGPoint {
        CGPoint(x: self.size.width * 0.1, y: self.size.height * 0.1)
    }
    
    /// A `CGPoint` that has x and y coordinates at 90% the size's width and height, respectively.
    func max() -> CGPoint {
        CGPoint(x: self.size.width * 0.9, y: self.size.height * 0.9)
    }
}
