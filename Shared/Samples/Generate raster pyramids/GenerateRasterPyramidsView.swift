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

struct GenerateRasterPyramidsView: View {
    /// The model that owns the working dataset and its build operation.
    @State private var model = Model()
    /// The current draw status of the map view.
    @State private var currentDrawStatus: DrawStatus = .inProgress
    /// A Boolean value indicating whether the map view is drawing.
    private var drawInProgress: Bool { currentDrawStatus == .inProgress }
    
    var body: some View {
        MapView(map: model.map, viewpoint: model.viewpoint)
            .onViewpointChanged(kind: .boundingGeometry) {
                model.viewpoint = $0
            }
            .onDrawStatusChanged { drawStatus in
                withAnimation { currentDrawStatus = drawStatus }
            }
            .interactionModes(model.isBusy ? [] : .all)
            .overlay(alignment: .top) {
                HStack {
                    Text("Status:")
                    Text(status)
                        .italic()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(.thinMaterial, ignoresSafeAreaEdges: .horizontal)
            }
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    if let operation = model.buildOperation {
                        ProgressView(operation.progress)
                            .progressViewStyle(.gauge)
                    } else if drawInProgress || model.isBusy {
                        ProgressView()
                    } else {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(.green)
                    }
                    
                    Spacer()
                    
                    Button("Build") {
                        Task { await model.buildPyramids() }
                    }
                    .disabled(drawInProgress || !model.canBuild)
                    
                    Spacer()
                    
                    Button("Delete") {
                        model.deletePyramids()
                    }
                    .disabled(drawInProgress || !model.canDelete)
                }
            }
            .errorAlert(presentingError: $model.error)
            .task { await model.setup() }
            .onTeardown { model.tearDown() }
    }
    
    /// The status text for the model.
    private var status: String {
        switch model.status {
        case .loading:
            "Loading raster"
        case .building:
            "Building pyramids"
        case .built:
            "Pyramids built"
        case .notBuilt(let additionalInfo):
            "Pyramids not built: \(additionalInfo)"
        case .error(let details):
            "Error: \(details)"
        }
    }
}

private extension GenerateRasterPyramidsView {
    @Observable
    final class Model {
        /// The state of the model.
        enum State {
            case loading
            case building
            case built
            case notBuilt(additionalInfo: String)
            case error(details: String)
        }
        
        /// A map with topographic basemap and a raster layer.
        let map = Map(basemapStyle: .arcGISLightGrayBase)
        /// The current viewpoint.
        var viewpoint: Viewpoint?
        /// The error that occurred during raster pyramid operations.
        var error: (any Error)?
        /// The status of the model's actions.
        private(set) var status: State = .loading
        
        /// The directory that contains the raster and its pyramids.
        @ObservationIgnored private var temporaryDirectory: URL?
        /// The raster for building pyramids.
        @ObservationIgnored private var raster: Raster?
        /// The raster pyramids for the raster.
        @ObservationIgnored private var pyramids: RasterPyramids?
        /// The operation that builds the raster pyramids.
        private(set) var buildOperation: BuildRasterPyramidsOperation?
        
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
            guard let rasterFile = prepareWorkingCopy() else {
                status = .error(details: "Failed to prepare working copy")
                return
            }
            let raster = Raster(fileURL: rasterFile)
            let layer = RasterLayer(raster: raster)
            self.raster = raster
            map.addOperationalLayer(layer)
            do {
                try await layer.load()
            } catch {
                self.error = error
                status = .error(details: "Failed to load raster layer")
            }
            if let extent = layer.fullExtent {
                viewpoint = Viewpoint(boundingGeometry: extent)
            }
            pyramids = raster.pyramids
            guard let pyramids else {
                // This property is nil until the raster is loaded.
                // After the raster is loaded, this property is non-nil for
                // file-based rasters that supports pyramids.
                status = .notBuilt(additionalInfo: "Doesn't support pyramid")
                return
            }
            if let info = pyramids.info, info.isEmbedded {
                // Pyramids can be embedded in the source raster dataset or
                // stored in a separate pyramid file (.ovr). We cannot
                // build pyramids for a raster if the pyramids are embedded.
                status = .notBuilt(additionalInfo: "Embedded")
            } else {
                status = .notBuilt(additionalInfo: "Ready")
            }
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
            map.removeAllOperationalLayers()
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
    /// The URL for the Yosemite GeoPDF raster.
    static var yosemiteGeoPDF: URL {
        Bundle.main.url(forResource: "YOSE_ParkMap", withExtension: "pdf")!
    }
}

/// A circular gauge progress view style.
private struct GaugeProgressViewStyle: ProgressViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        if let fractionCompleted = configuration.fractionCompleted {
            let gradientStops: [Gradient.Stop] = [
                .init(color: .accent, location: 0),
                .init(color: .accent, location: fractionCompleted),
                .init(color: .init(.tertiarySystemFill), location: fractionCompleted),
                .init(color: .init(.tertiarySystemFill), location: 1)
            ]
            let gradient = AngularGradient(gradient: .init(stops: gradientStops), center: .center)
            
            Image(systemName: "circle.fill")
                .foregroundStyle(gradient)
                .rotationEffect(.degrees(-90))
        }
    }
}

private extension ProgressViewStyle where Self == GaugeProgressViewStyle {
    /// A progress view that visually indicates its progress with a gauge.
    static var gauge: Self { .init() }
}
