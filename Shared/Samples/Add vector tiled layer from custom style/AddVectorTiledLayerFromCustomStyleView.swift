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

struct AddVectorTiledLayerFromCustomStyleView: View {
    @State private var map = Map(basemapStyle: .arcGISTopographic)
    
    var body: some View {
        MapView(map: map)
    }
}

private extension URL {
    /// The URL to the local vector tile package file of Dodge City, KS, USA.
    static var dodgeCityVectorTilePackage: URL {
        Bundle.main.url(forResource: "dodge_city", withExtension: "vtpk")!
    }
}
