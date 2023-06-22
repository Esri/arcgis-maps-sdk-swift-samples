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

extension RunValveIsolationTraceView {
    /// The different states of a utility network trace.
    enum TracingActivity: CaseIterable, CustomStringConvertible {
        case loadingServiceGeodatabase, loadingNetwork, startingLocation, runningTrace, none
        
        /// A human-readable label for the tracing activity.
        var description: String {
            switch self {
            case .loadingServiceGeodatabase: return "Loading service geodatabase…"
            case .loadingNetwork: return "Loading utility network…"
            case .startingLocation: return "Getting starting location feature…"
            case .runningTrace: return "Running isolation trace…"
            case .none: return ""
            }
        }
    }
}
