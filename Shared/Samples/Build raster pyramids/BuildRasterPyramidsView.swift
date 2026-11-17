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

struct BuildRasterPyramidsView: View {
    /// The model that manages the raster and its build pyramids operation.
    @State private var model = Model()
    /// A Boolean value indicating whether the pyramid level stepper is visible.
    @State private var showsLevelStepper = false
    /// The value of the stepper.
    @State private var stepperValue = 0
    /// The current draw status of the map view.
    @State private var drawStatus: DrawStatus = .inProgress
    /// The map view's size for calculating a full-resolution viewpoint.
    @State private var viewSize: CGSize?
    /// The center of the current map viewpoint.
    @State private var viewpointCenter: Point?
    /// The error that occurred during raster pyramid operations.
    @State private var error: (any Error)?
    /// The status of the sample.
    @State private var status: State = .loading
    
    /// A Boolean value indicating whether the sample is performing an action.
    private var isBusy: Bool {
        switch status {
        case .loading, .building:
            true
        case .built, .notBuilt, .failed:
            false
        }
    }
    
    /// The pyramid level for calculation. Zero represents full resolution.
    private var pyramidLevel: Int {
        // The pyramid level is the inverse of the stepper value, i.e.,
        // the stepper shows the full resolution as the maximum value.
        model.levelCount - stepperValue
    }
    
    var body: some View {
        MapViewReader { mapView in
            MapView(map: model.map)
                .onViewpointChanged(kind: .centerAndScale) { newViewpoint in
                    viewpointCenter = newViewpoint.targetGeometry as? Point
                }
                .onDrawStatusChanged { newDrawStatus in
                    withAnimation { drawStatus = newDrawStatus }
                }
                .interactionModes(isBusy ? [] : .all)
                .onGeometryChange(for: CGSize.self, of: \.size) { newSize in
                    viewSize = newSize
                }
                .overlay(alignment: .top) {
                    Text("Status: \(Text(status.description).italic())")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(.thinMaterial, ignoresSafeAreaEdges: .horizontal)
                }
                .toolbar {
                    ToolbarItemGroup(placement: .bottomBar) {
                        if let operation = model.pyramids?.activeBuildOperation {
                            ProgressView(operation.progress)
                                .progressViewStyle(.gauge)
                        } else if drawStatus == .inProgress || isBusy {
                            ProgressView()
                        } else {
                            Image(systemName: "checkmark.circle")
                                .foregroundStyle(.green)
                        }
                        
                        Spacer()
                        
                        // A button to show or hide the pyramid level stepper.
                        Button(
                            "Zoom",
                            systemImage: "arrow.up.left.and.down.right.magnifyingglass"
                        ) {
                            showsLevelStepper = true
                            Task {
                                await setViewpoint(pyramidLevel: pyramidLevel, mapView: mapView)
                            }
                        }
                        .labelStyle(.iconOnly)
                        .onChange(of: model.levelCount) { _, newLevelCount in
                            stepperValue = min(stepperValue, newLevelCount)
                        }
                        .disabled(drawStatus == .inProgress || isBusy || viewSize == nil)
                        .popover(isPresented: $showsLevelStepper) {
                            Group {
                                if model.levelCount > 0 {
                                    Stepper(
                                        value: $stepperValue,
                                        in: 0...model.levelCount,
                                        step: 1
                                    ) {
                                        Text("Pyramid level: \(pyramidLevel)")
                                    }
                                    .onChange(of: stepperValue) {
                                        Task {
                                            await setViewpoint(pyramidLevel: pyramidLevel, mapView: mapView)
                                        }
                                    }
                                    .disabled(isBusy)
                                } else {
                                    VStack {
                                        Text("Pyramid level: \(stepperValue)")
                                        Text("Zoomed to full resolution. Build pyramids to enable levels.")
                                            .font(.caption)
                                    }
                                }
                            }
                            .padding()
                            .frame(idealWidth: 320)
                            .presentationBackground(.thinMaterial)
                            .presentationCompactAdaptation(.popover)
                        }
                        
                        Spacer()
                        
                        // Buttons to build or delete the raster pyramids.
                        if status == .built {
                            Button("Delete") {
                                do {
                                    try model.deletePyramids()
                                    status = .notBuilt(additionalInfo: "Ready")
                                } catch {
                                    status = .failed(details: "Failed to delete pyramids, \(error.localizedDescription)")
                                }
                            }
                            .disabled(drawStatus == .inProgress || !model.canDelete)
                        } else {
                            Button("Build") {
                                Task {
                                    do {
                                        status = .building
                                        try await model.buildPyramids()
                                        status = .built
                                    } catch {
                                        status = .failed(details: "Failed to build pyramids, \(error.localizedDescription)")
                                    }
                                }
                            }
                            .disabled(drawStatus == .inProgress || !model.canBuild)
                        }
                    }
                }
                .errorAlert(presentingError: $error)
                .task {
                    do {
                        status = .loading
                        try await model.setUp()
                        if let initialViewpoint = model.initialViewpoint {
                            await mapView.setViewpoint(initialViewpoint)
                        }
                    } catch {
                        status = .failed(details: "Failed to load raster, \(error.localizedDescription)")
                    }
                    if let pyramids = model.pyramids {
                        if let info = pyramids.info {
                            if info.isEmbedded {
                                // Pyramids can be embedded in the source raster
                                // dataset or stored in a separate pyramid file
                                // (.ovr). We cannot build pyramids for a raster
                                // if the pyramids are embedded.
                                status = .notBuilt(additionalInfo: "Embedded")
                            } else if info.fileURL != nil {
                                // If the pyramids are not embedded, and the
                                // file path is not nil, then the pyramids are
                                // built.
                                status = .built
                            } else {
                                fatalError("Unexpected state: pyramids.info is not-nil but pyramids aren't built or embedded.")
                            }
                        } else {
                            status = .notBuilt(additionalInfo: "Ready")
                        }
                    } else {
                        // This property is nil until the raster is loaded.
                        // After the raster is loaded, this property is non-nil for
                        // file-based rasters that supports pyramids.
                        status = .notBuilt(additionalInfo: "Doesn't support pyramid")
                    }
                }
                .onTeardown { model.tearDown() }
        }
    }
    
    /// Sets the map view's viewpoint to the requested pyramid level.
    /// - Parameters:
    ///   - level: The pyramid level.
    ///   - mapView: The map view to set the viewpoint.
    private func setViewpoint(pyramidLevel level: Int, mapView: MapViewProxy) async {
        guard let viewSize,
              let viewpointCenter,
              let viewpoint = model.makeViewpoint(
                viewSize: viewSize,
                level: level,
                center: viewpointCenter
              ) else {
            return
        }
        await mapView.setViewpoint(viewpoint)
    }
    
    /// The state of the sample.
    private enum State: Equatable {
        case loading
        case building
        case built
        case notBuilt(additionalInfo: String)
        case failed(details: String)
        
        /// The status text for the model.
        var description: String {
            switch self {
            case .loading:
                "Loading raster"
            case .building:
                "Building pyramids"
            case .built:
                "Pyramids built"
            case .notBuilt(let additionalInfo):
                "Pyramids not built: \(additionalInfo)"
            case .failed(let details):
                "Failure: \(details)"
            }
        }
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
