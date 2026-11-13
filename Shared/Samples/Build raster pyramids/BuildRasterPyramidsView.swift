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
    /// The pyramid level for calculation. Zero represents full resolution.
    private var pyramidLevel: Int {
        // The pyramid level is the inverse of the stepper value, i.e.,
        // the stepper shows the full resolution as the maximum value.
        model.levelCount - stepperValue
    }
    /// The current draw status of the map view.
    @State private var drawStatus: DrawStatus = .inProgress
    /// The map view's size for calculating a full-resolution viewpoint.
    @State private var viewSize: CGSize?
    /// The center of the current map viewpoint.
    @State private var viewpointCenter: Point?
    /// A Boolean value indicating whether the map view is drawing.
    private var drawInProgress: Bool { drawStatus == .inProgress }
    
    var body: some View {
        MapViewReader { mapView in
            MapView(map: model.map)
                .onViewpointChanged(kind: .centerAndScale) { newViewpoint in
                    viewpointCenter = newViewpoint.targetGeometry as? Point
                }
                .onDrawStatusChanged { newDrawStatus in
                    withAnimation { drawStatus = newDrawStatus }
                }
                .interactionModes(model.isBusy ? [] : .all)
                .onGeometryChange(for: CGSize.self, of: \.size) { newSize in
                    viewSize = newSize
                }
                .overlay(alignment: .top) {
                    Text("Status: \(Text(status).italic())")
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
                        
                        // A button to show or hide the pyramid level stepper.
                        Button {
                            showsLevelStepper = true
                            Task {
                                await setViewpoint(pyramidLevel: pyramidLevel, mapView: mapView)
                            }
                        } label: {
                            Image(systemName: "arrow.up.left.and.down.right.magnifyingglass")
                        }
                        .onChange(of: model.levelCount) { _, newLevelCount in
                            stepperValue = min(stepperValue, newLevelCount)
                        }
                        .disabled(model.isBusy || viewSize == nil)
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
                                    .disabled(model.isBusy)
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
                        
                        // A button to build or delete the raster pyramids.
                        Button(model.status == .built ? "Delete" : "Build") {
                            if model.status == .built {
                                model.deletePyramids()
                            } else {
                                Task { await model.buildPyramids() }
                            }
                        }
                        .disabled(drawInProgress || (model.status == .built ? !model.canDelete : !model.canBuild))
                    }
                }
                .errorAlert(presentingError: $model.error)
                .task {
                    await model.setup()
                    if let initialViewpoint = model.initialViewpoint {
                        await mapView.setViewpoint(initialViewpoint)
                    }
                }
                .onTeardown { model.tearDown() }
        }
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
    
    /// Sets the map view's viewpoint to the requested pyramid level.
    /// - Parameters:
    ///   - level: The pyramid level.
    ///   - mapView: The map view to set the viewpoint.
    private func setViewpoint(pyramidLevel level: Int, mapView: MapViewProxy) async {
        guard let viewSize,
              let viewpointCenter,
              let viewpoint = model.makeViewpoint(
                for: viewSize,
                level: level,
                center: viewpointCenter
              ) else {
            return
        }
        await mapView.setViewpoint(viewpoint)
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
