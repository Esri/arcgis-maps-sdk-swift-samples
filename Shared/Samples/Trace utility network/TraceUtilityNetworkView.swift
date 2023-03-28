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
    @StateObject var model = TraceUtilityNetworkView.Model()
    
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
}

extension TraceUtilityNetworkView {
    /// The trace types supported for this sample.
    var supportedTraceTypes: [UtilityTraceParameters.TraceType] {
        return [.connected, .subnetwork, .upstream, .downstream]
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
