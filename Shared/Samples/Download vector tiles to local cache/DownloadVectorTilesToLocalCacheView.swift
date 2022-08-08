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

struct DownloadVectorTilesToLocalCacheView: View {
    /// A Boolean value indicating whether to download vector tiles.
    @State private var isDownloading = false
    
    /// A Boolean value indicating whether to cancel and the job.
    @State private var isCancellingJob = false
    
    /// The view model for this sample.
    @StateObject private var model = Model()
    
    var body: some View {
        GeometryReader { geometry in
            MapViewReader { mapView in
                MapView(map: model.map)
                    .interactionModes(isDownloading ? [] : [.pan, .zoom])
                    .onScaleChanged { model.maxScale = $0 * 0.1 }
                    .alert(isPresented: $model.isShowingAlert, presentingError: model.error)
                    .task {
                        await model.initializeVectorTilesTask()
                    }
                    .onDisappear {
                        Task { await model.cancelJob() }
                    }
                    .overlay {
                        Rectangle()
                            .stroke(.red, lineWidth: 2)
                            .padding(EdgeInsets(top: 20, leading: 20, bottom: 44, trailing: 20))
                            .opacity(model.isShowingResults ? 0 : 1)
                    }
                    .overlay {
                        if isDownloading,
                           let progress = model.exportVectorTilesJob?.progress {
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
                                    // Sets cancelling the job and downloading to false.
                                    isCancellingJob = false
                                    isDownloading = false
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
                            Button("Download Vector Tiles") {
                                isDownloading = true
                            }
                            .disabled(model.isDownloadDisabled || isDownloading)
                            .task(id: isDownloading) {
                                // Ensures downloading is true.
                                guard isDownloading else { return }
                                
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
                                
                                // Downloads the vector tiles.
                                await model.downloadVectorTiles(extent: extent)
                                // Sets downloading to false when the download finishes.
                                isDownloading = false
                            }
                            .sheet(isPresented: $model.isShowingResults) {
                                // Removes the temporary files when the cover is dismissed.
                                model.removeTemporaryFiles()
                            } content: {
                                NavigationView {
                                    MapView(map: model.downloadedVectorTilesMap)
                                        .navigationTitle("Vector tile package")
                                        .navigationBarTitleDisplayMode(.inline)
                                        .toolbar {
                                            ToolbarItem(placement: .confirmationAction) {
                                                Button("Done") {
                                                    model.isShowingResults = false
                                                }
                                            }
                                        }
                                }
                                .highPriorityGesture(DragGesture())
                            }
                        }
                    }
            }
        }
    }
}

private extension DownloadVectorTilesToLocalCacheView {
    /// A view model for this sample.
    @MainActor
    class Model: ObservableObject {
        /// A Boolean value indicating whether the download button is disabled.
        @Published var isDownloadDisabled = true
        
        /// A Boolean value indicating whether to show the result map.
        @Published var isShowingResults = false
        
        /// A Boolean value indicating whether to show an alert.
        @Published var isShowingAlert = false
        
        /// The error shown in the alert.
        @Published var error: Error? {
            didSet { isShowingAlert = error != nil }
        }
        
        /// A map with a basemap from the vector tiled layer results.
        @Published var downloadedVectorTilesMap: Map!
        
        /// The export vector tiles job.
        @Published var exportVectorTilesJob: ExportVectorTilesJob!
        
        /// The export vector tiles task.
        private var exportVectorTilesTask: ExportVectorTilesTask!
        
        /// The vector tiled layer from the downloaded result.
        private var vectorTiledLayerResults: ArcGISVectorTiledLayer!
        
        /// A URL to the directory temporarily storing all items.
        private let temporaryDirectory = makeTemporaryDirectory()
        
        /// A URL to the temporary directory to store the exported vector tile package.
        private let vtpkTemporaryURL: URL
        
        /// A URL to the temporary directory to store the style item resources.
        private let styleTemporaryURL: URL
        
        /// The max scale for the export vector tiles job.
        var maxScale: Double?
        
        /// A map with a night streets basemap style and an initial viewpoint.
        let map: Map
        
        init() {
            // Initializes the map.
            map = Map(basemapStyle: .arcGISStreetsNight)
            map.initialViewpoint = Viewpoint(latitude: 34.049, longitude: -117.181, scale: 1e4)
            
            // Initializes the URL for the directory containing vector tile packages.
            vtpkTemporaryURL = temporaryDirectory
                .appendingPathComponent("myTileCache")
                .appendingPathExtension("vtpk")
            
            // Initializes the URL for the directory containing style item resources.
            styleTemporaryURL = temporaryDirectory
                .appendingPathComponent("styleItemResources", isDirectory: true)
        }
        
        deinit {
            // Removes the temporary directory.
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        
        /// Initializes the vector tiles task.
        func initializeVectorTilesTask() async {
            do {
                // Waits for the map to load.
                try await map.load()
                // Gets the map's base layers.
                guard let vectorTiledLayer = map.basemap?.baseLayers.first as? ArcGISVectorTiledLayer else { return }
                // Creates the export vector tiles task from the base layers' URL.
                exportVectorTilesTask = ExportVectorTilesTask(url: vectorTiledLayer.url)
                // Loads the export vector tiles task.
                try await exportVectorTilesTask.load()
                // Enables the download button.
                isDownloadDisabled = false
            } catch {
                self.error = error
            }
        }
        
        /// Creates the export tiles parameters for the export vector tiles task.
        /// - Parameters:
        ///   - areaOfInterest: The area of interest to export vector tiles for.
        ///   - maxScale: The max scale of for the export vector tiles job.
        /// - Returns: An `ExportVectorTilesParameters` if there are no errors. Otherwise, it returns `nil`.
        private func makeExportTilesParameters(
            areaOfInterest: Envelope,
            maxScale: Double
        ) async -> ExportVectorTilesParameters? {
            do {
                return try await exportVectorTilesTask.makeDefaultExportVectorTilesParameters(
                    areaOfInterest: areaOfInterest,
                    maxScale: maxScale
                )
            } catch {
                self.error = error
                return nil
            }
        }
        
        /// Downloads the vector tiles within the area of interest.
        /// - Parameter extent: The area of interest's envelope to download vector tiles.
        func downloadVectorTiles(extent: Envelope) async {
            // Ensures that exporting vector tiles is allowed.
            if let vectorTileSourceInfo = exportVectorTilesTask.vectorTileSourceInfo,
               vectorTileSourceInfo.exportTilesAllowed,
               let maxScale = maxScale,
               // Creates the parameters for the export vector tiles job.
               let parameters = await makeExportTilesParameters(areaOfInterest: extent, maxScale: maxScale) {
                // Creates the export vector tiles job based on the parameters
                // and temporary URLs.
                exportVectorTilesJob = exportVectorTilesTask.makeExportVectorTilesJob(
                    parameters: parameters,
                    vectorTileCacheURL: vtpkTemporaryURL,
                    itemResourceCacheURL: styleTemporaryURL
                )
                
                // Starts the job.
                exportVectorTilesJob.start()
                
                defer { exportVectorTilesJob = nil }
                
                do {
                    // Awaits the output of the job.
                    let output = try await exportVectorTilesJob.output
                    
                    // Gets the vector tile and item resource cache from the output.
                    if let vectorTileCache = output.vectorTileCache,
                       let itemResourceCache = output.itemResourceCache {
                        // Creates a vector tiled layer from the caches.
                        vectorTiledLayerResults = ArcGISVectorTiledLayer(
                            vectorTileCache: vectorTileCache,
                            itemResourceCache: itemResourceCache
                        )
                        
                        // Creates a map with a basemap from the vector tiled layer results.
                        downloadedVectorTilesMap = Map(basemap: Basemap(baseLayer: vectorTiledLayerResults))
                        
                        // Sets the initial viewpoint of the result map.
                        downloadedVectorTilesMap.initialViewpoint = Viewpoint(targetExtent: extent.expanded(by: 0.9))
                        
                        // Shows the downloaded results.
                        isShowingResults = true
                    }
                } catch is CancellationError {
                    // Does nothing if the error is a cancellation error.
                } catch {
                    // Shows an alert with the error if the job fails.
                    self.error = error
                }
            }
        }
        
        /// Cancels the export vector tiles job.
        func cancelJob() async {
            // Cancels the export vector tiles job.
            await exportVectorTilesJob?.cancel()
            exportVectorTilesJob = nil
        }
        
        /// Removes any temporary files.
        func removeTemporaryFiles() {
            try? FileManager.default.removeItem(at: vtpkTemporaryURL)
            try? FileManager.default.removeItem(at: styleTemporaryURL)
        }
        
        /// Creates a temporary directory.
        /// - Returns: The URL to the temporary directory.
        private static func makeTemporaryDirectory() -> URL {
            do {
                return try FileManager.default.url(
                    for: .itemReplacementDirectory,
                    in: .userDomainMask,
                    appropriateFor: Bundle.main.bundleURL,
                    create: true
                )
            } catch {
                fatalError("A temporary directory could not be created.")
            }
        }
    }
}

private extension MapViewProxy {
    /// Creates an envelope from the given rectangle.
    /// - Parameter viewRect: The rectangle to create an envelope of.
    /// - Returns: An envelope of the given rectangle.
    func envelope(fromViewRect viewRect: CGRect) -> Envelope? {
        guard let min = location(fromScreenPoint: CGPoint(x: viewRect.minX, y: viewRect.minY)),
              let max = location(fromScreenPoint: CGPoint(x: viewRect.maxX, y: viewRect.maxY)) else {
            return nil
        }
        return Envelope(min: min, max: max)
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
