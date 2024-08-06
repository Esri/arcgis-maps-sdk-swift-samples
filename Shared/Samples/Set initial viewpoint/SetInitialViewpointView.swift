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

struct SetInitialViewpointView: View {
    /// A map with a basemap and an initial viewpoint
    @State private var map: Map = {
        let map = Map(basemapStyle: .arcGISImageryStandard)
        map.initialViewpoint = Viewpoint(boundingGeometry: .potashPonds)
        return map
    }()
    
    var body: some View {
        MapView(map: map)
    }
}

private extension Geometry {
    /// The area around Potash Ponds, Moab, Utah
    static var potashPonds: Envelope {
        Envelope(
            xRange: -12211308.778729 ... -12208257.879667,
            yRange: 4645116.003309 ... 4650542.535773,
            spatialReference: .webMercator
        )
    }
}
#Preview {
    SetInitialViewpointView()
}
