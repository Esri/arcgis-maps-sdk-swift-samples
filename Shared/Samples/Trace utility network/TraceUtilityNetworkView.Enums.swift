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
    }
    
    /// The different activities a user will traverse while performing a utility network trace.
    enum TracingActivity: Equatable {
        /// Indicates the user is setting starting points and barriers.
        case settingPoints(pointType: PointType)
        /// Indicates the user is setting the trace type.
        case settingType
        /// Indicates the user has started a trace and is awaiting results.
        case tracing
        /// Indicates the user is viewing trace results.
        case viewingResults
    }
}
