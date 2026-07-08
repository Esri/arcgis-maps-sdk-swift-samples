// Copyright 2026 Esri
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

struct DownloadRasterTilesToLocalCacheView: View {
    /// The view model for the sample.
    @State private var model = Model()

    /// A Boolean value indicating whether the exported tiles preview is showing.
    @State private var isShowingPreview = false

    /// The error shown in the error alert.
    @State private var error: (any Error)?

    var body: some View {
        GeometryReader { geometryProxy in
            MapViewReader { mapViewProxy in
                MapView(map: model.map)
                    .interactionModes(model.exportTileCacheJob == nil ? [.pan, .zoom] : [])
                    .onScaleChanged { model.mapViewScale = $0 }
                    .onDisappear {
                        Task { await model.cancelExport() }
                    }
                    .overlay {
                        // Draws a red rectangle to emphasize the extent that
                        // will be exported.
                        let rect = exportExtentRect(in: geometryProxy.size)
                        Rectangle()
                            .stroke(.red, lineWidth: 2)
                            .frame(width: rect.width, height: rect.height)
                    }
                    .overlay {
                        if let job = model.exportTileCacheJob {
                            exportProgressView(job: job)
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .bottomBar) {
                            Button("Export Tiles") {
                                Task {
                                    await exportTiles(
                                        mapViewProxy: mapViewProxy,
                                        size: geometryProxy.size
                                    )
                                }
                            }
                            .disabled(model.exportTileCacheJob != nil)
                        }
                    }
            }
        }
        .sheet(isPresented: $isShowingPreview, onDismiss: model.removePreview) {
            previewSheet
        }
        .errorAlert(presentingError: $error)
    }

    /// A progress indicator and cancel button shown while tiles are exporting.
    private func exportProgressView(job: ExportTileCacheJob) -> some View {
        VStack(spacing: 16) {
            Text("Exporting tiles")
            // Observes the job's progress to update the bar automatically.
            ProgressView(job.progress)
                .progressViewStyle(.linear)
            Button("Cancel", role: .cancel) {
                Task { await model.cancelExport() }
            }
        }
        .padding()
        .frame(maxWidth: 220)
        .background(.regularMaterial, in: .rect(cornerRadius: 12))
    }

    /// A sheet that previews the exported tile cache in its own map.
    private var previewSheet: some View {
        NavigationStack {
            if let previewMap = model.previewMap {
                MapView(map: previewMap)
                    .navigationTitle("Exported Tiles")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { isShowingPreview = false }
                        }
                    }
            }
        }
        .highPriorityGesture(DragGesture())
        .presentationSizing(.page)
    }

    /// Exports the tiles within the red rectangle and shows the preview sheet.
    /// - Parameters:
    ///   - mapViewProxy: The proxy used to convert screen points to locations.
    ///   - size: The size of the map view, used to locate the export extent.
    private func exportTiles(mapViewProxy: MapViewProxy, size: CGSize) async {
        // Creates an envelope from the centered square.
        guard let extent = mapViewProxy.envelope(fromViewRect: exportExtentRect(in: size)) else {
            return
        }
        do {
            try await model.exportTiles(extent: extent)
            isShowingPreview = true
        } catch {
            self.error = error
        }
    }

    /// Returns a square export extent centered in the map view.
    private func exportExtentRect(in size: CGSize) -> CGRect {
        let sideLength = min(size.width, size.height)
        return CGRect(
            x: (size.width - sideLength) / 2,
            y: (size.height - sideLength) / 2,
            width: sideLength,
            height: sideLength
        )
    }
}

extension DownloadRasterTilesToLocalCacheView {
    /// The model that stores the maps and runs the export task for this sample.
    @MainActor
    @Observable
    final class Model {
        /// A map with the World Ocean Base tiled layer as its basemap.
        let map: Map

        /// A map that previews the exported tile cache, if one exists.
        private(set) var previewMap: Map?

        /// The export job currently downloading the tile package, if any.
        private(set) var exportTileCacheJob: ExportTileCacheJob?

        /// The tiled layer that provides both the basemap and the export source.
        private let tiledLayer = ArcGISTiledLayer(url: .worldOceanBase)

        /// The task that exports tiles from the tiled layer's service.
        private let exportTask = ExportTileCacheTask(url: .worldOceanBase)

        /// A URL to the temporary directory storing the exported tile package.
        private let temporaryDirectory = FileManager.createTemporaryDirectory()

        /// The URL for the exported tile cache file.
        private var tileCacheURL: URL?

        /// The current scale of the map view, used to derive the export scale range.
        var mapViewScale = 0.0

        init() {
            // Creates a map with a basemap made from the tiled layer, and limits
            // its minimum scale to avoid requesting a huge download.
            map = Map(basemap: Basemap(baseLayer: tiledLayer))
            map.minScale = 1e7
            map.initialViewpoint = Viewpoint(
                center: Point(latitude: 34, longitude: -117),
                scale: 1e7
            )
        }

        deinit {
            // Removes the temporary directory and all of its content.
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        /// Exports the tiles within an extent to a local tile package and builds
        /// a preview map from the result.
        /// - Parameter extent: The geographic area of interest to export.
        func exportTiles(extent: Envelope) async throws {
            // Loads the task to access its service metadata.
            try await exportTask.load()
            guard let mapServiceInfo = exportTask.mapServiceInfo,
                  mapServiceInfo.allowsExportTiles else {
                throw ExportNotSupportedError()
            }

            // Creates the parameters for the export tile cache job.
            let parameters = try await makeExportTileCacheParameters(areaOfInterest: extent)

            // Uses the compact V2 format (.tpkx) when supported, otherwise the
            // legacy compact format (.tpk).
            let fileExtension = mapServiceInfo.allowsExportTileCacheCompactV2 ? "tpkx" : "tpk"
            let downloadURL = temporaryDirectory
                .appendingPathComponent(
                    "myTileCache",
                    isDirectory: false
                )
                .appendingPathExtension(fileExtension)

            try? FileManager.default.removeItem(at: downloadURL)

            // Creates the export job based on the parameters and temporary URL.
            exportTileCacheJob = exportTask.makeExportTileCacheJob(
                parameters: parameters,
                downloadFileURL: downloadURL
            )
            defer {
                exportTileCacheJob = nil
            }
            guard let exportTileCacheJob else { return }

            // Starts the job.
            exportTileCacheJob.start()

            // Awaits the resulting tile cache and builds a preview map from it.
            let tileCache = try await exportTileCacheJob.output
            let previewLayer = ArcGISTiledLayer(tileCache: tileCache)
            let previewMap = Map(basemap: Basemap(baseLayer: previewLayer))
            previewMap.initialViewpoint = Viewpoint(boundingGeometry: extent)
            self.previewMap = previewMap
        }

        /// Creates the export tile cache parameters.
        /// - Parameter areaOfInterest: The area of interest to create the parameters for.
        /// - Returns: An `ExportTileCacheParameters` if there are no errors.
        private func makeExportTileCacheParameters(areaOfInterest: Envelope) async throws -> ExportTileCacheParameters {
            // Uses the current map view scale when available; otherwise falls
            // back to the map's configured minScale.
            let effectiveScale = mapViewScale > 0 ? mapViewScale : map.minScale
            let maxScale = (effectiveScale ?? 0) / 2
            let minScale = (effectiveScale ?? 0) * 2

            // Returns the default parameters for the export tile cache task.
            return try await exportTask.makeDefaultExportTileCacheParameters(
                areaOfInterest: areaOfInterest,
                minScale: minScale,
                maxScale: maxScale
            )
        }

        /// Cancels the running export job, if one exists.
        func cancelExport() async {
            if let job = exportTileCacheJob.take() {
                await job.cancel()
            }
        }

        /// Releases the preview map and removes the exported tile package.
        func removePreview() {
            previewMap = nil
            let contents = (try? FileManager.default.contentsOfDirectory(
                at: temporaryDirectory,
                includingPropertiesForKeys: nil
            )) ?? []
            for url in contents {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
}

private extension DownloadRasterTilesToLocalCacheView.Model {
    struct ExportNotSupportedError: LocalizedError {
        let errorDescription: String? = "Exporting tiles is not supported for the service."
    }
}

private extension FileManager {
    /// Creates a temporary directory.
    /// - Returns: The URL of the created directory.
    static func createTemporaryDirectory() -> URL {
        try! FileManager.default.url(
            for: .itemReplacementDirectory,
            in: .userDomainMask,
            appropriateFor: FileManager.default.temporaryDirectory,
            create: true
        )
    }
}

private extension URL {
    /// The URL of the World Ocean Base (for Export) tile service.
    static var worldOceanBase: URL {
        URL(string: "https://tiledbasemaps.arcgis.com/arcgis/rest/services/Ocean/World_Ocean_Base/MapServer")!
    }
}

#Preview {
    NavigationStack {
        DownloadRasterTilesToLocalCacheView()
    }
}
