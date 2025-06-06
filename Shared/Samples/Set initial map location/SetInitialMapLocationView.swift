// Copyright 2025 Esri
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

struct SetInitialMapLocationView: View {
    /// A map with a basemap and an initial viewpoint location.
    @State private var map: Map = {
        /// Creates a map with an ESRI imagery basemap.
        let map = Map(basemapStyle: .arcGISImagery)
        
        /// Centers the map on a latitude and longitude, zoomed to a specific scale.
        map.initialViewpoint = Viewpoint(latitude: -33.867886, longitude: -63.985, scale: 10000)
        
        return map
    }()
    
    var body: some View {
        MapView(map: map)
    }
}

#Preview {
    SetInitialMapLocationView()
}
