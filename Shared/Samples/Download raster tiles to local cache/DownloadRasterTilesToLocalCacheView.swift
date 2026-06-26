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

    /// The current scale of the map view, used as the export's minimum scale.
    @State private var mapViewScale = 0.0

    /// A Boolean value indicating whether the exported tiles preview is showing.
    @State private var isShowingPreview = false

    /// The error shown in the error alert.
    @State private var error: Error?

    /// The insets that define the export extent within the map view.
    private let extentInsets = EdgeInsets(top: 20, leading: 20, bottom: 44, trailing: 20)

    var body: some View {
        MapViewReader { mapViewProxy in
            GeometryReader { geometryProxy in
                MapView(map: model.map)
                    .onScaleChanged { mapViewScale = $0 }
                    .overlay {
                        // Draws a red rectangle to emphasize the extent that
                        // will be exported.
                        Rectangle()
                            .stroke(.red, lineWidth: 2)
                            .padding(extentInsets)
                    }
                    .overlay(alignment: .center) {
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
            Text("Exporting tiles…")
            // Observes the job's progress to update the bar automatically.
            ProgressView(job.progress)
                .progressViewStyle(.linear)
            Button("Cancel", role: .destructive) {
                Task { await model.cancelExport() }
            }
        }
        .padding()
        .frame(maxWidth: 220)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    /// A sheet that previews the exported tile cache in its own map.
    @ViewBuilder private var previewSheet: some View {
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
    }

    /// Exports the tiles within the red rectangle and shows the preview sheet.
    /// - Parameters:
    ///   - mapViewProxy: The proxy used to convert screen points to locations.
    ///   - size: The size of the map view, used to locate the export extent.
    private func exportTiles(mapViewProxy: MapViewProxy, size: CGSize) async {
        // Converts the red rectangle's corners to a geographic envelope.
        let rect = CGRect(
            x: extentInsets.leading,
            y: extentInsets.top,
            width: size.width - extentInsets.leading - extentInsets.trailing,
            height: size.height - extentInsets.top - extentInsets.bottom
        )
        guard
            let min = mapViewProxy.location(fromScreenPoint: CGPoint(x: rect.minX, y: rect.maxY)),
            let max = mapViewProxy.location(fromScreenPoint: CGPoint(x: rect.maxX, y: rect.minY))
        else { return }

        do {
            try await model.exportTiles(
                extent: Envelope(min: min, max: max),
                currentScale: mapViewScale
            )
            isShowingPreview = true
        } catch {
            self.error = error
        }
    }
}

extension DownloadRasterTilesToLocalCacheView {
    /// The model that stores the maps and runs the export task for this sample.
    @MainActor
    @Observable
    final class Model {
        /// A map of the world street map tiled layer.
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

        init() {
            // Creates a map with a basemap made from the tiled layer, and limits
            // its minimum scale to avoid requesting a huge download.
            map = Map(basemap: Basemap(baseLayer: tiledLayer))
            map.minScale = 1e7
            map.initialViewpoint = Viewpoint(
                center: Point(x: -117, y: 34, spatialReference: .wgs84),
                scale: 1e7
            )
        }

        deinit {
            // Removes the temporary directory and all of its content.
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        /// Exports the tiles within an extent to a local tile package and builds
        /// a preview map from the result.
        /// - Parameters:
        ///   - extent: The geographic area of interest to export.
        ///   - currentScale: The map's current scale, used as the minimum scale.
        func exportTiles(extent: Envelope, currentScale: Double) async throws {
            // Loads the task to access its service metadata.
            try await exportTask.load()
            guard
                let mapServiceInfo = exportTask.mapServiceInfo,
                mapServiceInfo.allowsExportTiles
            else {
                throw ExportError.notSupported
            }

            // Uses the current scale as the min scale and the tiled layer's max
            // scale as the max scale.
            let maxScale = tiledLayer.maxScale ?? 0
            let minScale = Swift.max(currentScale, maxScale)

            // Builds the default parameters for the extent and scale range.
            let parameters = try await exportTask.makeDefaultExportTileCacheParameters(
                areaOfInterest: extent,
                minScale: minScale,
                maxScale: maxScale
            )

            // Uses the compact V2 format (.tpkx) when supported, otherwise the
            // legacy compact format (.tpk).
            let fileExtension = mapServiceInfo.allowsExportTileCacheCompactV2 ? "tpkx" : "tpk"
            let downloadURL = temporaryDirectory
                .appendingPathComponent("myTileCache", isDirectory: false)
                .appendingPathExtension(fileExtension)

            // Creates and starts the export job.
            let job = exportTask.makeExportTileCacheJob(
                parameters: parameters,
                downloadFileURL: downloadURL
            )
            exportTileCacheJob = job
            job.start()
            defer { exportTileCacheJob = nil }

            // Awaits the resulting tile cache and builds a preview map from it.
            let tileCache = try await job.output
            let previewLayer = ArcGISTiledLayer(tileCache: tileCache)
            let previewMap = Map(basemap: Basemap(baseLayer: previewLayer))
            previewMap.initialViewpoint = Viewpoint(boundingGeometry: extent)
            self.previewMap = previewMap
        }

        /// Cancels the running export job, if one exists.
        func cancelExport() async {
            await exportTileCacheJob?.cancel()
            exportTileCacheJob = nil
        }

        /// Releases the preview map and removes the exported tile package.
        func removePreview() {
            previewMap = nil
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
    }
}

private extension DownloadRasterTilesToLocalCacheView.Model {
    /// An error indicating the service does not support exporting tiles.
    enum ExportError: LocalizedError {
        case notSupported

        var errorDescription: String? {
            switch self {
            case .notSupported:
                return "Exporting tiles is not supported for the service."
            }
        }
    }
}

private extension FileManager {
    /// Creates a uniquely named temporary directory and returns its URL.
    static func createTemporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(ProcessInfo().globallyUniqueString)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

private extension URL {
    /// The URL of the World Ocean Base (for Export) tile service.
    static var worldOceanBase: URL {
        URL(string: "https://tiledbasemaps.arcgis.com/arcgis/rest/services/Ocean/World_Ocean_Base/MapServer")!
    }
}
