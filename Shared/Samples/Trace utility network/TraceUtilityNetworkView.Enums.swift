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

extension TraceUtilityNetworkView {
    /// The types of points used during a utility network trace.
    enum PointType: String {
        /// A point which marks a location for a trace to stop.
        case barrier
        /// A point which marks a location for a trace to begin.
        case start
        
        /// A displayable name the point type.
        var label: String {
            switch self {
            case .barrier:
                return "Barrier"
            case .start:
                return "Start"
            }
        }
    }
    
    /// The different states of a utility network trace.
    enum TracingActivity: Equatable {
        /// Starting points and barriers are being added.
        case settingPoints(pointType: PointType)
        /// The trace completed successfully.
        case traceCompleted
        /// The trace failed.
        case traceFailed(description: String)
        /// The trace is running.
        case traceRunning
    }
}
