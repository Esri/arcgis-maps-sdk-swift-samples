// Copyright 2024 Esri
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

struct MonitorChangesToDrawStatusView: View {
    /// A map with a topographic basemap.
    @State private var map: Map = {
        let map = Map(basemapStyle: .arcGISTopographic)
        
        // Initially centers the map on San Fransisco, CA, USA area.
        map.initialViewpoint = Viewpoint(
            center: Point(x: -13623300, y: 4548100, spatialReference: .webMercator),
            scale: 32e4
        )
        
        return map
    }()
    
    /// A Boolean value indicating whether the map is currently drawing.
    @State private var mapIsDrawing = false
    
    var body: some View {
        MapView(map: map)
            .onDrawStatusChanged { drawStatus in
                // Updates the state when the map's draw status changes.
                mapIsDrawing = drawStatus == .inProgress
            }
            .overlay(alignment: .top) {
                // The drawing status text at the top of the screen.
                Text(mapIsDrawing ? "Drawing..." : "Drawing completed.")
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(8)
                    .background(.regularMaterial, ignoresSafeAreaEdges: .horizontal)
            }
            .overlay(alignment: .center) {
                // The progress view in the center of the screen that shows when the map is drawing.
                if mapIsDrawing {
                    ProgressView()
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                        .shadow(radius: 50)
                }
            }
    }
}

#Preview {
    MonitorChangesToDrawStatusView()
}
