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
        /// A map with light gray basemap and a raster layer.
        let map = Map(basemapStyle: .arcGISLightGrayBase)
        /// The directory that contains the raster and its pyramids.
        private let temporaryDirectory = FileManager.default.temporaryDirectory
            .appending(
                component: ProcessInfo.processInfo.globallyUniqueString,
                directoryHint: .isDirectory
            )
        /// The raster for building pyramids.
        @ObservationIgnored private var raster: Raster?
        /// The raster layer.
        @ObservationIgnored private var layer: RasterLayer?
        /// The initial viewpoint for the map view.
        @ObservationIgnored private(set) var initialViewpoint: Viewpoint?
        
        /// The raster pyramids for the raster.
        var pyramids: RasterPyramids? {
            raster?.pyramids
        }
        
        /// The number of pyramid levels.
        var levelCount: Int {
            pyramids?.info?.levelCount ?? 0
        }
        
        /// A Boolean value indicating whether the build pyramids operation
        /// can start.
        var canBuild: Bool {
            guard let pyramids,
                  pyramids.info == nil,
                  pyramids.activeBuildOperation == nil else {
                // Don't build if the pyramids already exist, or there is an
                // active build operation.
                return false
            }
            return true
        }
        
        /// A Boolean value indicating whether the pyramids can be deleted.
        var canDelete: Bool {
            guard let pyramids,
                  let info = pyramids.info,
                  !info.isEmbedded,
                  pyramids.activeBuildOperation == nil else {
                // Don't delete if the pyramids don't exist, are embedded in the
                // raster, or there is an active build operation.
                return false
            }
            return true
        }
        
        init() {
            try? FileManager.default.createDirectory(
                at: temporaryDirectory,
                withIntermediateDirectories: true
            )
        }
        
        /// Sets up the model.
        @MainActor
        func setUp() async throws {
            let destination = temporaryDirectory.appendingPathComponent(URL.yosemiteGeoPDF.lastPathComponent)
            try FileManager.default.copyItem(at: .yosemiteGeoPDF, to: destination)
            let raster = Raster(fileURL: destination)
            let layer = RasterLayer(raster: raster)
            try await layer.load()
            self.raster = raster
            self.layer = layer
            map.addOperationalLayer(layer)
            if let extent = layer.fullExtent {
                initialViewpoint = Viewpoint(boundingGeometry: extent)
            }
        }
        
        /// Creates a viewpoint at the current map center and requested level.
        /// - Parameters:
        ///   - viewSize: The size of the map view.
        ///   - level: The pyramid level; zero for full resolution.
        ///   - center: The current map viewpoint's center.
        /// - Returns: A viewpoint, or `nil` if the level is invalid.
        func makeViewpoint(viewSize: CGSize, level: Int, center: Point) -> Viewpoint? {
            guard (0...levelCount).contains(level),
                  let layer, layer.loadStatus == .loaded,
                  let spatialReference = layer.fullExtent?.spatialReference,
                  let center = GeometryEngine.project(center, into: spatialReference),
                  let info = raster?.info else {
                return nil
            }
            let scale = Double(2 << level)
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
        
        /// Builds the pyramids for the raster.
        @MainActor
        func buildPyramids() async throws {
            guard let pyramids else { return }
            // You can customize the parameters. The default parameters are used
            // here for simplicity.
            let parameters = BuildRasterPyramidsParameters()
            let operation = try pyramids.build(using: parameters)
            _ = try await operation.result
        }
        
        /// Deletes the pyramids for the owning raster.
        func deletePyramids() throws {
            guard let pyramids else { return }
            try pyramids.delete()
        }
        
        /// Tears down the model and cleans up resources.
        func tearDown() {
            if let layer = layer.take() {
                map.removeOperationalLayer(layer)
            }
            if let buildOperation = pyramids?.activeBuildOperation {
                buildOperation.cancel()
            }
            if let raster = raster.take() {
                raster.close()
            }
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
    }
}

private extension URL {
    /// The URL for the Yosemite geospatial PDF raster.
    static var yosemiteGeoPDF: URL {
        Bundle.main.url(forResource: "YOSE_ParkMap", withExtension: "pdf")!
    }
}
