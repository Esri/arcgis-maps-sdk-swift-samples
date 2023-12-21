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
    
    /// A Boolean value indicating whether to cancel the job.
    @State private var isCancellingJob = false
    
    /// A Boolean value indicating whether to show the result map.
    @State private var isShowingResults = false
    
    /// The map view's scale.
    @State private var mapViewScale = Double.zero
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    /// The view model for this sample.
    @StateObject private var model = Model()
    
    var body: some View {
        GeometryReader { geometry in
            MapViewReader { mapViewProxy in
                MapView(map: model.map)
                    .interactionModes(isDownloading ? [] : [.pan, .zoom])
                    .onScaleChanged { mapViewScale = $0 }
                    .errorAlert(presentingError: $error)
                    .task {
                        do {
                            try await model.initializeVectorTilesTask()
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
                            .opacity(isShowingResults ? 0 : 1)
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
                            .disabled(!model.allowsDownloadingVectorTiles || isDownloading)
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
                                guard let extent = mapViewProxy.envelope(fromViewRect: viewRect) else { return }
                                
                                // Downloads the vector tiles.
                                do {
                                    // Sets downloading to false when the download
                                    // finishes or errors occur.
                                    defer { isDownloading = false }
                                    // Sets the max scale to 10% of the map's scale to limit
                                    // the number of tiles exported.
                                    try await model.downloadVectorTiles(extent: extent, maxScale: mapViewScale * 0.1)
                                    // Shows results when the download finishes.
                                    isShowingResults = true
                                } catch {
                                    // Shows an alert if any errors occur.
                                    self.error = error
                                }
                            }
                            .sheet(isPresented: $isShowingResults) {
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
                                                    isShowingResults = false
                                                }
                                            }
                                        }
                                        .overlay(alignment: .top) {
                                            Text("Vector tiles downloaded.")
                                                .frame(maxWidth: .infinity, alignment: .center)
                                                .padding(8)
                                                .background(.thinMaterial, ignoresSafeAreaEdges: .horizontal)
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
    /// The model used to store the geo model and other expensive objects
    /// used in this view.
    @MainActor
    class Model: ObservableObject {
        /// A map with a basemap from the vector tiled layer results.
        private(set) var downloadedVectorTilesMap: Map!
        
        /// The export vector tiles job.
        @Published private(set) var exportVectorTilesJob: ExportVectorTilesJob!
        
        /// The export vector tiles task.
        @Published private(set) var exportVectorTilesTask: ExportVectorTilesTask!
        
        /// The vector tiled layer from the downloaded result.
        private var vectorTiledLayerResults: ArcGISVectorTiledLayer!
        
        /// A URL to the directory temporarily storing all items.
        private let temporaryDirectory = createTemporaryDirectory()
        
        /// A URL to the temporary directory to store the exported vector tile package.
        private let vtpkTemporaryURL: URL
        
        /// A URL to the temporary directory to store the style item resources.
        private let styleTemporaryURL: URL
        
        /// A Boolean value indicating whether the export task can be started.
        var allowsDownloadingVectorTiles: Bool {
            if let exportVectorTilesTask,
               // Only allows downloading when the task is loaded.
               exportVectorTilesTask.loadStatus == .loaded,
               // Ensures that the service allows exporting vector tiles.
               let vectorTileSourceInfo = exportVectorTilesTask.vectorTileSourceInfo {
                return vectorTileSourceInfo.allowsExportingTiles
            } else {
                return false
            }
        }
        
        /// A map with a night streets basemap style and an initial viewpoint.
        let map: Map = {
            let map = Map(basemapStyle: .arcGISStreetsNight)
            map.initialViewpoint = Viewpoint(latitude: 34.049, longitude: -117.181, scale: 1e4)
            // Sets the min scale to avoid requesting a huge download.
            map.minScale = 1e4
            return map
        }()
        
        init() {
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
        func initializeVectorTilesTask() async throws {
            guard exportVectorTilesTask == nil else { return }
            // Waits for the map to load.
            try await map.load()
            // Gets the map's base layers.
            guard let vectorTiledLayer = map.basemap?.baseLayers.first as? ArcGISVectorTiledLayer,
                  let url = vectorTiledLayer.url else { return }
            // Creates the export vector tiles task from the base layers' URL.
            let exportVectorTilesTask = ExportVectorTilesTask(url: url)
            // Loads the export vector tiles task.
            try await exportVectorTilesTask.load()
            self.exportVectorTilesTask = exportVectorTilesTask
        }
        
        /// Downloads the vector tiles within the area of interest at given scale.
        /// - Parameters:
        ///   - extent: The area of interest's envelope to export vector tiles.
        ///   - maxScale: The map scale which determines how far in to export
        ///   the vector tiles. Set to `0` to include all levels of detail.
        func downloadVectorTiles(extent: Envelope, maxScale: Double) async throws {
            // Creates the parameters for the export vector tiles job.
            let parameters = try await exportVectorTilesTask.makeDefaultExportVectorTilesParameters(
                areaOfInterest: extent,
                maxScale: maxScale
            )
            
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
                downloadedVectorTilesMap.initialViewpoint = Viewpoint(boundingGeometry: extent.expanded(by: 0.9))
            }
        }
        
        /// Cancels the export vector tiles job.
        func cancelJob() async {
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
        DownloadVectorTilesToLocalCacheView()
    }
}
