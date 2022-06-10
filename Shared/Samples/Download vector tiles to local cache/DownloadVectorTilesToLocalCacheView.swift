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

import SwiftUI
import ArcGIS

struct DownloadVectorTilesToLocalCacheView: View {
    /// A Boolean value indicating whether to show an alert.
    @State private var showAlert = false
    
    /// The error shown in the alert.
    @State private var error: Error?
    
    @State private var taskIsLoaded = false
    
    /// The extent of the area of interest.
    @State private var extent: Envelope?
    
    /// The max scale of the export task.
    @State private var maxScale: Double?
    
    /// The export task.
    @State private var exportVectorTilesTask: ExportVectorTilesTask?
    
    /// The export vector tiles job.
    @State private var job: ExportVectorTilesJob?
    
    /// A Boolean value indicating whether to show the downloaded vector tile result.
    @State private var showResults = false
    
    /// The vector tiled layer of the results.
    @State private var vectorTiledLayer: ArcGISVectorTiledLayer?
    
    /// A map with an ArcGIS streets night basemap style.
    @StateObject private var map = Map(basemapStyle: .arcGISStreetsNight)
    
    /// A graphics overlay to display the area of interest.
    @StateObject private var graphicsOverlay = GraphicsOverlay()
    
    /// A red box to represent the area of interest.
    @StateObject private var areaOfInterestGraphic = Graphic(symbol: SimpleLineSymbol(style: .solid, color: .red, width: 2))
    
    /// A Boolean value indicating whether downloading is an option.
    private var canDownload: Bool {
        return taskIsLoaded && job == nil
    }
    
    /// A map with a basemap containing the vector tiled layer of the results.
    private var resultsMap: Map {
        let map = Map(basemap: Basemap(baseLayer: vectorTiledLayer))
        if let extent = extent {
            map.initialViewpoint = Viewpoint(targetExtent: extent)
        }
        return map
    }
    
    /// An error representing different download errors.
    private enum DownloadError: Error {
        case notAllowed
    }
    
    /// Creates a temporary directory to store all items.
    private func createTemporaryDirectory() {
        do {
            try FileManager.default.createDirectory(at: .temporaryDirectory, withIntermediateDirectories: false)
        } catch {
            self.error = error
            showAlert = true
        }
    }
    
    /// Removes all temporary files.
    private func removeTemporaryFiles() {
        try? FileManager.default.removeItem(at: .vtpkTemporaryURL)
        try? FileManager.default.removeItem(at: .styleTemporaryURL)
        try? FileManager.default.removeItem(at: .temporaryDirectory)
    }
    
    /// Sets up and loads the export vector tiles task.
    private func configureTask() async {
        do {
            try await map.load()
            guard let vectorTiledLayer = map.basemap?.baseLayers.first as? ArcGISVectorTiledLayer else { return }
            
            // Creates the export vector tiles task.
            exportVectorTilesTask = ExportVectorTilesTask(url: vectorTiledLayer.url)
            try await exportVectorTilesTask?.load()
            taskIsLoaded = exportVectorTilesTask?.loadStatus == .loaded
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
        extent = Envelope(min: min, max: max)
        // Updates the geometry of the graphic.
        areaOfInterestGraphic.geometry = extent
    }
    
    /// Initiates the export vector tiles task to download a tile package.
    private func initiateDownload(exportTask: ExportVectorTilesTask) async {
        // Ensures extent and max scale have values.
        guard let extent = extent else { return }
        guard let maxScale = maxScale else { return }
        
        do {
            // Creates the parameters for the export task.
            let parameters = try await exportTask.createDefaultExportVectorTilesParameters(
                areaOfInterest: extent,
                maxScale: maxScale
            )
            // Creates an export vector tiles job based on the parameters.
            let job = exportTask.exportVectorTiles(
                parameters: parameters,
                vectorTileCacheURL: .vtpkTemporaryURL,
                itemResourceCacheURL: .styleTemporaryURL
            )
            // Starts the job.
            job.start()
            self.job = job
        } catch {
            self.error = error
            showAlert = true
        }
    }
    
    /// Handles the download results.
    private func handleDownloadResults() async {
        // Ensures an export vector tiles job exists.
        guard let job = job else { return }
        
        // Awaits and saves the job's results.
        let result = await job.result
        
        switch result {
        case .success(let output):
            if let vectorTileCache = output.vectorTileCache,
               let itemResourceCache = output.itemResourceCache {
                // Creates a vector tiled layer from the result's
                // vector tile and item resource caches.
                vectorTiledLayer = ArcGISVectorTiledLayer(
                    vectorTileCache: vectorTileCache,
                    itemResourceCache: itemResourceCache
                )
                showResults = true
                self.job = nil
            }
        case .failure(let error):
            self.error = error
            showAlert = true
        }
    }
    
    /// Attempts to download the vector tiles based on the area of interest.
    private func downloadVectorTiles() async {
        // Ensures the vector tile source info can be exported.
        if let exportVectorTilesTask = exportVectorTilesTask,
           let vectorTileSourceInfo = exportVectorTilesTask.vectorTileSourceInfo,
           vectorTileSourceInfo.exportTilesAllowed {
            // Initiates the download.
            await initiateDownload(exportTask: exportVectorTilesTask)
            // Handles the results of the download.
            await handleDownloadResults()
        } else {
            // Shows an error if exporting is not allowed.
            error = DownloadError.notAllowed
            showAlert = true
        }
    }
    
    var body: some View {
        VStack {
            GeometryReader { geometry in
                MapViewReader { mapViewProxy in
                    MapView(
                        map: map,
                        viewpoint: Viewpoint(latitude: 34.049, longitude: -117.181, scale: 1e4),
                        graphicsOverlays: [graphicsOverlay]
                    )
                    .onVisibleAreaChanged { _ in
                        // Updates the area of interest when the visible area changes.
                        updateAreaOfInterest(mapView: mapViewProxy, geometry: geometry)
                    }
                    .onScaleChanged { scale in
                        // Updates the max scale to 10% of the map's scale.
                        maxScale = scale * 0.1
                    }
                    .onAppear {
                        // Creates the temporary directory.
                        createTemporaryDirectory()
                        // Adds the area of interest graphic to the graphics overlay.
                        graphicsOverlay.addGraphic(areaOfInterestGraphic)
                    }
                    .task {
                        // Configure the export vector tiles task.
                        await configureTask()
                    }
                    .disabled(!canDownload)
                    .fullScreenCover(isPresented: $showResults) {
                        NavigationView {
                            MapView(map: resultsMap)
                                .interactiveDismissDisabled()
                                .navigationTitle("Vector tile package")
                                .navigationBarTitleDisplayMode(.inline)
                                .toolbar {
                                    ToolbarItem(placement: .navigationBarTrailing) {
                                        Button("Done") {
                                            showResults = false
                                        }
                                    }
                                }
                        }
                    }
                    .overlay {
                        // FIXME: Temporary Placeholder for Progress View
                        if job != nil {
                            ProgressView()
                                .padding()
                                .background(.white.opacity(0.6))
                                .clipShape(RoundedRectangle(cornerRadius: 15.0))
                        }
                    }
                }
            }
            HStack {
                Button("Download Vector Tiles") {
                    Task {
                        // Downloads the vector tiles in the area of interest.
                        await downloadVectorTiles()
                    }
                }
                .disabled(!canDownload)
            }
            .padding()
        }
        .alert(isPresented: $showAlert, presentingError: error)
        .onDisappear {
            // Removes the temporary files.
            removeTemporaryFiles()
        }
    }
}

private extension GeometryProxy {
    /// A `CGPoint` that has x and y coordinates at 10% the size's width and height, respectively.
    func min() -> CGPoint {
        return CGPoint(x: self.size.width * 0.1, y: self.size.height * 0.1)
    }
    
    /// A `CGPoint` that has x and y coordinates at 90% the size's width and height, respectively.
    func max() -> CGPoint {
        return CGPoint(x: self.size.width * 0.9, y: self.size.height * 0.9)
    }
}

private extension URL {
    /// A URL to the directory temporarily storing all items.
    static let temporaryDirectory = FileManager
        .default
        .temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    
    /// A URL to the temporary directory to store the exported vector tile package.
    static let vtpkTemporaryURL = temporaryDirectory
        .appendingPathComponent("myTileCache", isDirectory: false)
        .appendingPathExtension("vtpk")
    
    /// A URL to the temporary directory to store the style item resources.
    static let styleTemporaryURL = temporaryDirectory
        .appendingPathComponent("styleItemResources", isDirectory: true)
}
