// Copyright 2023 Esri
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

struct TraceUtilityNetworkView: View {
    /// The view model for the sample.
    @StateObject private var model = TraceUtilityNetworkView.Model()
    
    var body: some View {
        GeometryReader { geometryProxy in
            VStack(spacing: .zero) {
                if let hint = model.hint {
                    Text(hint)
                        .padding([.bottom])
                }
                MapViewReader { mapViewProxy in
                    MapView(
                        map: model.map,
                        viewpoint: .initialViewpoint,
                        graphicsOverlays: [model.points]
                    )
                    .onSingleTapGesture { screenPoint, mapPoint in
                        model.lastSingleTap = (screenPoint, mapPoint)
                    }
                    .selectionColor(.yellow)
                    .confirmationDialog(
                        "Select trace type",
                        isPresented: $model.traceTypeSelectorIsOpen,
                        titleVisibility: .visible,
                        actions: { traceTypePickerButtons }
                    )
                    .confirmationDialog(
                        "Select terminal",
                        isPresented: $model.terminalSelectorIsOpen,
                        titleVisibility: .visible,
                        actions: { terminalPickerButtons }
                    )
                    .onChange(of: model.traceTypeSelectorIsOpen) { _ in
                        // If type selection is closed and a new trace wasn't initialized we can
                        // figure that the user opted to cancel.
                        if !model.traceTypeSelectorIsOpen && model.pendingTraceParameters == nil {
                            model.reset()
                        }
                    }
                    .onDisappear {
                        ArcGISEnvironment.authenticationManager.arcGISCredentialStore.removeAll()
                    }
                    .task {
                        await model.setup()
                    }
                    .task(id: model.lastSingleTap?.mapPoint) {
                        guard case .settingPoints = model.tracingActivity,
                              let lastSingleTap = model.lastSingleTap else {
                            return
                        }
                        if let feature = await model.identifyFeatureAt(
                            lastSingleTap.screenPoint,
                            with: mapViewProxy
                        ) {
                            model.add(feature, at: lastSingleTap.mapPoint)
                        }
                    }
                    .task(id: model.tracingActivity) {
                        model.updateUserHint()
                        if model.tracingActivity == .tracing {
                            do {
                                try await model.trace()
                                model.tracingActivity = .viewingResults
                            } catch {
                                model.tracingActivity = .none
                                model.updateUserHint(withMessage: "An error occurred")
                            }
                        }
                    }
                }
                traceMenu
                    .frame(width: geometryProxy.size.width)
                    .background(.thinMaterial)
            }
        }
    }
    
    /// The menu at the bottom of the screen that guides the user through running a trace.
    var traceMenu: some View {
        HStack(spacing: 5) {
            switch model.tracingActivity {
            case .none:
                Button("Start a New Trace") {
                    withAnimation {
                        model.tracingActivity = .settingType
                        model.traceTypeSelectorIsOpen.toggle()
                    }
                }
                .padding()
            case .settingPoints:
                controlsForSettingPoints
            case .settingType:
                EmptyView()
            case .tracing:
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .padding()
            case .viewingResults:
                Button("Reset", role: .destructive) {
                    model.reset()
                }
                .padding()
            }
        }
    }
}

extension TraceUtilityNetworkView {
    /// The buttons and picker shown to the user while setting points.
    @ViewBuilder
    private var controlsForSettingPoints: some View {
        Picker("Add starting points & barriers", selection: pointType) {
            ForEach([PointType.start, PointType.barrier], id: \.self) { type in
                Text(type.rawValue.capitalized).tag(type)
            }
        }
        .padding()
        .pickerStyle(.segmented)
        Button("Trace") {
            model.tracingActivity = .tracing
        }
        .disabled(model.pendingTraceParameters?.startingLocations.isEmpty ?? true)
        .padding()
        Button("Reset", role: .destructive) {
            model.reset()
        }
        .padding()
    }
    
    /// Determines whether the user is setting starting points or barriers.
    ///
    /// - Note: This should only be used when the user is setting starting points or barriers. If
    /// this condition isn't present, gets will be inaccurate and sets will be ignored.
    private var pointType: Binding<PointType> {
        .init(
            get: {
                guard case .settingPoints(let pointType) = model.tracingActivity else {
                    return .start
                }
                return pointType
            },
            set: {
                guard case .settingPoints = model.tracingActivity else { return }
                model.tracingActivity = .settingPoints(pointType: $0)
            }
        )
    }
    
    /// The trace types supported for this sample.
    private var supportedTraceTypes: [UtilityTraceParameters.TraceType] {
        return [.connected, .subnetwork, .upstream, .downstream]
    }
    
    /// Buttons for each the available terminals on the last added utility element.
    @ViewBuilder
    private var terminalPickerButtons: some View {
        ForEach(model.lastAddedElement?.assetType.terminalConfiguration?.terminals ?? []) { terminal in
            Button(terminal.name) {
                model.lastAddedElement?.terminal = terminal
                model.updateUserHint(withMessage: "terminal: \(terminal.name)")
            }
        }
    }
    
    /// Buttons for each the supported trace types.
    ///
    /// When a trace type is selected, the pending trace is initialized as a new instance of trace
    /// parameters. The trace configuration can also be set. The user should set trace points next.
    @ViewBuilder
    private var traceTypePickerButtons: some View {
        ForEach(supportedTraceTypes, id: \.self) { type in
            Button(type.displayName) {
                model.makeTraceParameters(withTraceType: type)
            }
        }
    }
}

private extension UtilityTraceParameters.TraceType {
    /// The name of this trace type, capitalized.
    var displayName: String {
        String(describing: self).capitalized
    }
}

private extension Viewpoint {
    /// The initial viewpoint to be displayed when the sample is first opened.
    static var initialViewpoint: Viewpoint {
        .init(
            boundingGeometry: Envelope(
                xRange: (-9813547.35557238)...(-9813185.0602376),
                yRange: (5129980.36635111)...(5130215.41254146)
            )
        )
    }
}
