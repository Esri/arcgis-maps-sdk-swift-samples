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

struct MonitorChangesToMapLoadStatusView: View {
    /// A map with an imagery base map.
    @State private var map = Map(basemapStyle: .arcGISImagery)
    
    /// A string indicating the load status of the map.
    @State private var loadStatusText = LoadStatus.notLoaded.title
    
    var body: some View {
        // Create a map view to display the map.
        MapView(map: map)
            .overlay(alignment: .top) {
                Text("Load Status: \(loadStatusText)")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(8)
                    .background(.thinMaterial, ignoresSafeAreaEdges: .horizontal)
            }
            .task {
                // Listen for load status changes and set the load status text.
                for await loadStatus in map.$loadStatus {
                    loadStatusText = loadStatus.title
                }
            }
    }
}

private extension LoadStatus {
    /// The human readable name of the load status.
    var title: String {
        switch self {
        case .loaded:
            return "Loaded"
        case .loading:
            return "Loading"
        case .failed:
            return "Failed"
        case .notLoaded:
            return "Not Loaded"
        }
    }
}

#Preview {
    MonitorChangesToMapLoadStatusView()
}
