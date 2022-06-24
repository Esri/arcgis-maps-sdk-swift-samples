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
import Combine
import SwiftUI

struct GenerateOfflineMapView: View {
    /// A Boolean value indicating whether to show an alert.
    @State private var showAlert = false
    
    /// The error shown in the alert.
    @State private var error: Error?
    
    /// A Boolean value indicating whether to disable the generate offline map button.
    @State private var generateIsDisabled = true
    
    /// The a red rectangle representing the extent of the area of interest.
    @State private var areaOfInterest: Envelope?
    
    /// The offline map task.
    @State private var offlineMapTask: OfflineMapTask?
    
    /// The generate offline map job.
    @State private var generateOfflineMapJob: GenerateOfflineMapJob?
    
    /// The job's completed progress when generating the offline map. **NOTE: temporary placeholder for job progress view**.
    @State private var jobProgress: Double?
    
    /// A cancellable that updates the job's completed progress. **NOTE: temporary placeholder for job progress view**.
    @State private var cancellable: AnyCancellable?
    
    /// The offline map that is generated.
    @State private var offlineMap: Map?
    
    /// The online map that is loaded from a portal item.
    @StateObject private var onlineMap = Map(item: PortalItem.napervilleWaterNetwork)
    
    /// A graphics overlay consisting of the area of interest graphic.
    @StateObject private var graphicsOverlay = GraphicsOverlay(graphics: [
        Graphic(symbol: SimpleLineSymbol(style: .solid, color: .red, width: 2))
    ])
    
    /// The graphic for the area of interest.
    private var areaOfInterestGraphic: Graphic {
        graphicsOverlay.graphics.first!
    }
    
    /// Creates a temporary directory for the offline map.
    private func createTemporaryDirectory() {
        do {
            try FileManager.default.createDirectory(at: .temporaryDirectory, withIntermediateDirectories: false)
        } catch {
            self.error = error
            showAlert = true
        }
    }
    
    /// Removes the temporary directory.
    private func removeTemporaryDirection() {
        do {
            try FileManager.default.removeItem(at: .temporaryDirectory)
        } catch {
            self.error = error
            showAlert = true
        }
    }
    
    /// Updates the area of interest graphic to represent the new extent.
    private func updateAreaOfInterest(mapView: MapViewProxy, geometry: GeometryProxy) {
        // Creates the minimum point for an envelope, in the map
        // view’s spatial reference, from a point that is located
        // at 10% the width and height of the map view's frame.
        guard let min = mapView.location(fromScreenPoint: geometry.min()) else { return }
        
        // Creates the maximum point for an envelope, in the map
        // view’s spatial reference, from a point that is located
        // at 90% the width and height of the map view's frame.
        guard let max = mapView.location(fromScreenPoint: geometry.max()) else { return }
        
        // Creates an envelope from the min and max points.
        areaOfInterest = Envelope(min: min, max: max)
        // Updates the geometry of the graphic.
        areaOfInterestGraphic.geometry = areaOfInterest
    }
    
    /// Initializes the offline map task.
    private func configureOfflineMapTask() async {
        do {
            try await onlineMap.load()
            offlineMapTask = OfflineMapTask(portalItem: PortalItem.napervilleWaterNetwork)
            generateIsDisabled = false
        } catch {
            self.error = error
            showAlert = true
        }
    }
    
    /// Generates the offline map.
    private func generateOfflineMap() async {
        guard let offlineMapTask = offlineMapTask,
              let areaOfInterest = areaOfInterest else {
            return
        }
        
        do {
            // Creates the default parameters for the offline map task.
            let parameters = try await offlineMapTask.createDefaultGenerateOfflineMapParameters(areaOfInterest: areaOfInterest)
            
            // Creates the offline map job based on the parameters.
            let generateOfflineMapJob = offlineMapTask.generateOfflineMap(parameters: parameters, downloadDirectoryURL: .temporaryDirectory)
            self.generateOfflineMapJob = generateOfflineMapJob
            
            // Starts the job.
            generateOfflineMapJob.start()
            generateIsDisabled = true
            
            cancellable = generateOfflineMapJob.progress // **NOTE: temporary placeholder for job progress view**.
                .publisher(for: \.fractionCompleted)
                .receive(on: RunLoop.main)
                .sink { jobProgress =  $0 }
            
            // Awaits the results of the job and sets the offline map to the output.
            let output = try await generateOfflineMapJob.result.get()
            offlineMap = output.offlineMap
            
            // Sets the initial viewpoint of the offline map.
            offlineMap?.initialViewpoint = Viewpoint(targetExtent: areaOfInterest.expanded(by: 0.8))
            
            cancellable?.cancel() //  **NOTE: temporary placeholder for job progress view**.
            self.generateOfflineMapJob = nil
        } catch {
            self.error = error
            showAlert = true
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            MapViewReader { mapView in
                MapView(map: offlineMap ?? onlineMap, graphicsOverlays: offlineMap == nil ? [graphicsOverlay] : [])
                    .onViewpointChanged(kind: .centerAndScale) { _ in
                        if offlineMap == nil {
                            // Updates the area of interest when the visible area changes.
                            updateAreaOfInterest(mapView: mapView, geometry: geometry)
                        }
                    }
                    .interactionModes([.pan, .zoom])
                    .disabled(generateOfflineMapJob != nil)
                    .task {
                        await configureOfflineMapTask()
                        updateAreaOfInterest(mapView: mapView, geometry: geometry)
                    }
                    .onAppear {
                        createTemporaryDirectory()
                    }
                    .onDisappear {
                        removeTemporaryDirection()
                    }
                    .overlay {
                        // NOTE: Temporary placeholder for job progress view.
                        if let generateOfflineMapJob = generateOfflineMapJob {
                            VStack {
                                if let jobProgress = jobProgress {
                                    VStack {
                                        Text("\(jobProgress, format: .percent) completed")
                                        ProgressView(value: jobProgress, total: 1)
                                    }
                                    .frame(maxWidth: geometry.size.width * 0.5)
                                }
                                
                                Button("Cancel") {
                                    Task {
                                        await generateOfflineMapJob.cancel()
                                        if let cancellable = cancellable {
                                            cancellable.cancel()
                                        }
                                        self.generateOfflineMapJob = nil
                                        generateIsDisabled = false
                                    }
                                }
                                .padding(.top)
                            }
                            .padding()
                            .background(.white.opacity(0.9))
                            .clipShape(RoundedRectangle(cornerRadius: 15.0))
                            .shadow(radius: 3)
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .bottomBar) {
                            Button("Generate Offline Map") {
                                Task {
                                    await generateOfflineMap()
                                }
                            }
                            .disabled(generateIsDisabled)
                        }
                    }
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

private extension URL {
    /// A URL to a temporary directory.
    static var temporaryDirectory: URL {
        FileManager
            .default
            .temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
    }
}

private extension Envelope {
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
        CGPoint(x: self.size.width * 0.9, y: self.size.height * 0.90)
    }
}
