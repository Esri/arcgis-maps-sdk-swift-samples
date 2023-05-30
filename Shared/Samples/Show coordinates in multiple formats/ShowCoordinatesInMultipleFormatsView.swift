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

struct ShowCoordinatesInMultipleFormatsView: View {
    /// The model used to store the geo model and other expensive objects
    /// used in this view.
    private class Model: ObservableObject {
        /// A map with imagery basemap.
        let map = Map(basemapStyle: .arcGISImagery)
    }
    
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// A map with a topographic basemap.
    @State private var map: Map = {
        let map = Map(basemapStyle: .arcGISTopographic)
        map.initialViewpoint = Viewpoint(
            center: Point(x: -355_453, y: 7_548_720, spatialReference: .webMercator),
            scale: 3_000
        )
        return map
    }()
    
    @State private var viewpoint = Viewpoint(
        center: Point(x: -117, y: 34, spatialReference: .wgs84),
        scale: 1e5
    )
    
    var body: some View {
        // Create a map view to display the map.
        MapView(map: map)
            .onViewpointChanged(kind: .centerAndScale) {
                viewpoint = $0
                print(viewpoint)
            }
    }
}

