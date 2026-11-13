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
import Foundation
import Observation

extension BuildRasterPyramidsView {
    @Observable
    final class Model {
        /// The state of the model.
        enum State: Equatable {
            case loading
            case building
            case built
            case notBuilt(additionalInfo: String)
            case error(details: String)
        }
        
        /// A map with light gray basemap and a raster layer.
        let map = Map(basemapStyle: .arcGISLightGrayBase)
        /// The initial viewpoint for the map view.
        @ObservationIgnored private(set) var initialViewpoint: Viewpoint?
        /// The error that occurred during raster pyramid operations.
        var error: (any Error)?
        /// The status of the model's actions.
        private(set) var status: State = .loading
        
        /// The directory that contains the raster and its pyramids.
        @ObservationIgnored private var temporaryDirectory: URL?
        /// The raster for building pyramids.
        @ObservationIgnored private var raster: Raster?
        /// The raster layer.
        @ObservationIgnored private var layer: RasterLayer?
        /// The raster pyramids for the raster.
        @ObservationIgnored private var pyramids: RasterPyramids?
        /// The operation that builds the raster pyramids.
        private(set) var buildOperation: BuildRasterPyramidsOperation?
        /// The number of pyramid levels.
        var levelCount: Int {
            pyramids?.info?.levelCount ?? 0
        }
        
        /// A Boolean value indicating whether the model is performing an action.
        var isBusy: Bool {
            switch status {
            case .loading, .building:
                true
            case .built, .notBuilt, .error:
                false
            }
        }
        /// A Boolean value indicating whether the build pyramids operation
        /// can start.
        var canBuild: Bool {
            !isBusy &&
            raster?.loadStatus == .loaded &&
            pyramids != nil &&
            pyramids?.info == nil &&
            pyramids?.activeBuildOperation == nil &&
            buildOperation == nil
        }
        /// A Boolean value indicating whether the pyramids can be deleted.
        var canDelete: Bool {
            !isBusy &&
            raster?.loadStatus == .loaded &&
            pyramids?.info?.isEmbedded == false &&
            pyramids?.activeBuildOperation == nil &&
            buildOperation == nil
        }
        
        /// Sets up the model.
        @MainActor
        func setup() async {
            guard let rasterFileURL = prepareWorkingCopy() else { return }
            let raster = Raster(fileURL: rasterFileURL)
            let layer = RasterLayer(raster: raster)
            self.raster = raster
            do {
                try await layer.load()
            } catch {
                self.error = error
                status = .error(details: "Failed to load raster layer")
                return
            }
            self.layer = layer
            map.addOperationalLayer(layer)
            if let extent = layer.fullExtent {
                initialViewpoint = Viewpoint(boundingGeometry: extent)
            }
            pyramids = raster.pyramids
            guard let pyramids else {
                // This property is nil until the raster is loaded.
                // After the raster is loaded, this property is non-nil for
                // file-based rasters that supports pyramids.
                status = .notBuilt(additionalInfo: "Doesn't support pyramid")
                return
            }
            if let info = pyramids.info {
                if info.isEmbedded {
                    // Pyramids can be embedded in the source raster dataset or
                    // stored in a separate pyramid file (.ovr). We cannot
                    // build pyramids for a raster if the pyramids are embedded.
                    status = .notBuilt(additionalInfo: "Embedded")
                } else if info.fileURL != nil {
                    // If the pyramids are not embedded, and the file path is
                    // not nil, then the pyramids are built.
                    status = .built
                } else {
                    fatalError("Unexpected state: pyramids.info is not-nil but pyramids aren't built or embedded.")
                }
            } else {
                status = .notBuilt(additionalInfo: "Ready")
            }
        }
        
        /// Creates a viewpoint at the current map center and requested level.
        /// - Parameters:
        ///   - viewSize: The size of the map view.
        ///   - level: The pyramid level; zero for full resolution.
        ///   - center: The current map viewpoint's center.
        /// - Returns: A viewpoint, or `nil` if the level is invalid.
        func makeViewpoint(for viewSize: CGSize, level: Int, center: Point) -> Viewpoint? {
            guard (0...levelCount).contains(level),
                  let layer, layer.loadStatus == .loaded,
                  let spatialReference = layer.fullExtent?.spatialReference,
                  let center = GeometryEngine.project(center, into: spatialReference),
                  let info = raster?.info else {
                return nil
            }
            let scale = pow(2.0, Double(level))
            let width = viewSize.width * info.cellSizeX * scale
            let height = viewSize.height * info.cellSizeY * scale
            guard width > 0, height > 0 else { return nil }
            return Viewpoint(
                boundingGeometry: Envelope(
                    center: center,
                    width: width,
                    height: height
                )
            )
        }
        
        /// Copies the raster to a temporary directory. Each time uses a unique
        /// directory so the first display doesn't reuse previous pyramids.
        private func prepareWorkingCopy() -> URL? {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString)
            temporaryDirectory = directory
            do {
                let destination = directory.appendingPathComponent(URL.yosemiteGeoPDF.lastPathComponent)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try FileManager.default.copyItem(at: .yosemiteGeoPDF, to: destination)
                return destination
            } catch {
                try? FileManager.default.removeItem(at: directory)
                self.error = error
                status = .error(details: "Failed to copy raster")
                return nil
            }
        }
        
        /// Builds the pyramids for the raster.
        @MainActor
        func buildPyramids() async {
            guard let pyramids else { return }
            // You can customize the parameters. The default parameters are used
            // here for simplicity.
            let parameters = BuildRasterPyramidsParameters()
            do {
                status = .building
                let operation = try pyramids.build(using: parameters)
                buildOperation = operation
                defer { buildOperation = nil }
                _ = try await operation.result
                status = .built
            } catch {
                self.error = error
                status = .error(details: "Failed to build pyramids, \(error.localizedDescription)")
            }
        }
        
        /// Deletes the pyramids for the owning raster.
        func deletePyramids() {
            do {
                try pyramids?.delete()
                status = .notBuilt(additionalInfo: "Ready")
            } catch {
                self.error = error
                status = .error(details: "Failed to delete pyramids, \(error.localizedDescription)")
            }
        }
        
        /// Tears down the model and cleans up resources.
        func tearDown() {
            pyramids = nil
            if let layer = layer.take() {
                map.removeOperationalLayer(layer)
            }
            if let buildOperation = buildOperation.take() {
                buildOperation.cancel()
            }
            if let raster = raster.take() {
                raster.close()
            }
            if let temporaryDirectory = temporaryDirectory.take() {
                try? FileManager.default.removeItem(at: temporaryDirectory)
            }
        }
    }
}

private extension URL {
    /// The URL for the Yosemite geospatial PDF raster.
    static var yosemiteGeoPDF: URL {
        Bundle.main.url(forResource: "YOSE_ParkMap", withExtension: "pdf")!
    }
}
