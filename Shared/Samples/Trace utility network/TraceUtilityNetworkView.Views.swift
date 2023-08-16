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

extension TraceUtilityNetworkView {
    /// The buttons and picker shown to the user while setting points.
    @ViewBuilder private var controlsForSettingPoints: some View {
        Group {
            Picker("Add starting points & barriers", selection: pointType) {
                ForEach([PointType.start, PointType.barrier], id: \.self) { type in
                    Text(type.label)
                }
            }
            .pickerStyle(.segmented)
            .frame(minWidth: 100, maxWidth: 300)
            
            Spacer()
            
            Button("Trace") {
                model.tracingActivity = .traceRunning
            }
            .disabled(model.pendingTraceParameters?.startingLocations.isEmpty ?? true)
            
            Spacer()
            
            Button("Reset", role: .destructive) {
                model.reset()
            }
        }
        .disabled(model.tracingActivity == .traceRunning)
    }
    
    /// A binding to the type of the starting point being set.
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
    
    /// Buttons for each the available terminals on the last added utility element.
    @ViewBuilder var terminalPickerButtons: some View {
        ForEach(model.lastAddedElement?.assetType.terminalConfiguration?.terminals ?? []) { terminal in
            Button(terminal.name) {
                model.lastAddedElement?.terminal = terminal
                model.updateUserHint(withMessage: "terminal: \(terminal.name)")
            }
        }
    }
    
    /// The menu at the bottom of the screen that guides the user through running a trace.
    var traceMenu: some View {
        Group {
            switch model.tracingActivity {
            case .none:
                Menu("Start a New Trace") {
                    traceTypePickerButtons
                }
            case .settingPoints, .traceRunning:
                controlsForSettingPoints
                    .alert(
                        "Select terminal",
                        isPresented: $model.terminalSelectorIsOpen,
                        actions: { terminalPickerButtons }
                    )
            case .traceCompleted, .traceFailed:
                Spacer()
                Button("Reset", role: .destructive) {
                    model.reset()
                }
                Spacer()
            }
        }
    }
    
    /// Buttons for the supported trace types.
    ///
    /// When a trace type is selected, the pending trace is initialized as a new instance of trace
    /// parameters. The trace configuration can also be set. The user should set trace points next.
    @ViewBuilder var traceTypePickerButtons: some View {
        ForEach(supportedTraceTypes, id: \.self) { type in
            Button(type.displayName) {
                model.setTraceParameters(ofType: type)
                model.tracingActivity = .settingPoints(pointType: .start)
            }
        }
    }
}

private extension UtilityTraceParameters.TraceType {
    /// The name of this trace type, capitalized.
    var displayName: String {
        switch self {
        case .connected:
            return "Connected"
        case .downstream:
            return "Downstream"
        case .isolation:
            return "Isolation"
        case .loops:
            return "Loops"
        case .shortestPath:
            return "Shortest Path"
        case .subnetwork:
            return "Subnetwork"
        case .upstream:
            return "Upstream"
        @unknown default:
            return "Unknown"
        }
    }
}
