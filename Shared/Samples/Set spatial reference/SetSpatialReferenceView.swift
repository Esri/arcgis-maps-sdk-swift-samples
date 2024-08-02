//  Copyright © 2024 Esri. All rights reserved.
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

struct SetSpatialReferenceView: View {
    /// A map with spatial reference and a basemap.
    @State private var map: Map = {
        let map = Map(spatialReference: .worldBonne)
        map.basemap = Basemap(
            baseLayer: ArcGISMapImageLayer(url: .worldCities)
        )
        return map
    }()
    
    var body: some View {
        MapView(map: map)
    }
}

private extension SpatialReference {
    /// The spatial reference for the sample World Bonne (WKID: 54024).
    static var worldBonne: Self { SpatialReference(wkid: WKID(54024)!)! }
}

private extension URL {
    /// The URL to the World Cities image layer for the basemap.
    static var worldCities: URL {
        URL(string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/SampleWorldCities/MapServer")!
    }
}

#Preview {
    SetSpatialReferenceView()
}

