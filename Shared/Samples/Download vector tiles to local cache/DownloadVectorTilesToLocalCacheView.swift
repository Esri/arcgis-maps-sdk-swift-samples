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
            MapViewReader { mapViewProxy in
                MapView(map: model.map)
                    .interactionModes([.pan, .zoom])
                    .onScaleChanged { model.maxScale = $0 * 0.1 }
                    .disabled(isDownloading)
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
                            .frame(width: geometry.size.width * 0.8, height: geometry.size.height * 0.8)
                        
                        if isDownloading {
                            VStack {
                                VStack {
                                    if let progress = model.exportVectorTilesJob?.progress {
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
                                        // Sets cancelling the job and downloading to false.
                                        isCancellingJob = false
                                        isDownloading = false
                                    }
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
                                // Downloads the vector tiles.
                                await model.downloadVectorTiles(mapView: mapViewProxy, geometry: geometry)
                                // Sets downloading to false when the download finishes.
                                isDownloading = false
                            }
                            .fullScreenCover(isPresented: $model.isShowingResults) {
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
                            }
                        }
                    }
            }
        }
    }
}

private extension DownloadVectorTilesToLocalCacheView {
    /// A view model for this sample.
    @MainActor class Model: ObservableObject {
        /// A Boolean value indicating whether the download button is disabled.
        @Published var isDownloadDisabled = true
        
        /// A Boolean value indicating whether to show the result map.
        @Published var isShowingResults = false
        
        /// A Boolean value indicating whether to show an alert.
        @Published var isShowingAlert = false
        
        /// The error shown in the alert.
        @Published var error: Error?
        
        /// A map with a basemap from the vector tiled layer results.
        @Published var downloadedVectorTilesMap: Map!
        
        /// The export vector tiles job.
        @Published var exportVectorTilesJob: ExportVectorTilesJob!
        
        /// The export vector tiles task.
        private var exportVectorTilesTask: ExportVectorTilesTask!
        
        /// The vector tiled layer from the downloaded result.
        private var vectorTiledLayerResults: ArcGISVectorTiledLayer!
        
        /// A URL to the directory temporarily storing all items.
        private let temporaryDirectoryURL: URL
        
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
            
            // Initializes the URL for the temporary directory.
            temporaryDirectoryURL = FileManager
                .default
                .temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
            
            // Initializes the URL for the directory containing vector tile packages.
            vtpkTemporaryURL = temporaryDirectoryURL
                .appendingPathComponent("myTileCache")
                .appendingPathExtension("vtpk")
            
            // Initializes the URL for the directory containing style item resources.
            styleTemporaryURL = temporaryDirectoryURL
                .appendingPathComponent("styleItemResources", isDirectory: true)
            
            
            // Creates a temporary directory for the files.
            makeTemporaryDirectory()
        }
        
        deinit {
            // Removes the temporary directory.
            try? FileManager.default.removeItem(at: temporaryDirectoryURL)
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
                isShowingAlert = true
            }
        }
        
        /// Creates the export tiles parameters for the export vector tiles task.
        /// - Parameters:
        ///   - areaOfInterest: The area of interest to export vector tiles for.
        ///   - maxScale: The max scale of for the export vector tiles job.
        /// - Returns: `ExportVectorTilesParameters` if there are no errors. Otherwise, it returns `nil`.
        private func makeExportTilesParameters(
            for areaOfInterest: Envelope,
            with maxScale: Double
        ) async -> ExportVectorTilesParameters? {
            do {
                return try await exportVectorTilesTask.createDefaultExportVectorTilesParameters(
                    areaOfInterest: areaOfInterest,
                    maxScale: maxScale
                )
            } catch {
                self.error = error
                isShowingAlert = true
                return nil
            }
        }
        
        /// Downloads the vector tiles within the area of interest.
        /// - Parameters:
        ///   - mapView: A map view proxy used to convert the min and max screen points to the map
        ///   view's spatial reference.
        ///   - geometry: A geometry proxy used to reference the min and max screen points that
        ///   represent the area of interest.
        func downloadVectorTiles(mapView: MapViewProxy, geometry: GeometryProxy) async {
            // Ensures that exporting vector tiles is allowed.
            if let vectorTileSourceInfo = exportVectorTilesTask.vectorTileSourceInfo,
               vectorTileSourceInfo.exportTilesAllowed {
                // Creates the min and max points for the envelope.
                guard let min = mapView.location(fromScreenPoint: geometry.min()),
                      let max = mapView.location(fromScreenPoint: geometry.max()),
                      let maxScale = maxScale,
                      // Creates the envelope representing the area of interest.
                      case let extent = Envelope(min: min, max: max),
                      // Creates the default parameters based on the extent and max scale.
                      let parameters = await makeExportTilesParameters(for: extent, with: maxScale) else {
                    return
                }
                
                // Creates the export vector tiles job based on the parameters
                // and temporary URLs.
                exportVectorTilesJob = exportVectorTilesTask.exportVectorTiles(
                    parameters: parameters,
                    vectorTileCacheURL: vtpkTemporaryURL,
                    itemResourceCacheURL: styleTemporaryURL
                )
                
                // Starts the job.
                exportVectorTilesJob.start()
                
                // Awaits the result of the job
                let result = await exportVectorTilesJob.result
                
                // Sets the job to nil.
                exportVectorTilesJob = nil
                
                switch result {
                case .success(let output):
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
                case .failure(let error):
                    // Shows an alert with the error if the job fails and the
                    // error is not a cancellation error.
                    guard !(error is CancellationError) else { return }
                    self.error = error
                    isShowingAlert = true
                }
            }
        }
        
        /// Cancels the export vector tiles job.
        func cancelJob() async {
            // Cancels the export vector tiles job.
            await exportVectorTilesJob?.cancel()
            exportVectorTilesJob = nil
            // Removes any temporary files.
            removeTemporaryFiles()
        }
        
        /// Creates the temporary directory.
        private func makeTemporaryDirectory() {
            do {
                try FileManager.default.createDirectory(at: temporaryDirectoryURL, withIntermediateDirectories: false)
            } catch {
                self.error = error
                isShowingAlert = true
            }
        }
        
        /// Removes any temporary files.
        func removeTemporaryFiles() {
            try? FileManager.default.removeItem(at: vtpkTemporaryURL)
            try? FileManager.default.removeItem(at: styleTemporaryURL)
        }
    }
}

private extension DownloadVectorTilesToLocalCacheView {
    struct LinearProgressStyle: ProgressViewStyle {
        func makeBody(configuration: Configuration) -> some View {
            let fractionCompleted = configuration.fractionCompleted ?? 0
            
            VStack {
                Text("\(fractionCompleted, format: .percent) completed")
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray5))
                    
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.accentColor)
                        .frame(width: 200 * fractionCompleted)
                }
                .frame(maxWidth: 200, maxHeight: 8)
            }
        }
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
