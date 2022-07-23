// Copyright 2022 Esri
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

import SwiftUI
import ArcGIS

struct DisplayMapMobileMapPackage: View {
    /// A map with imagery basemap.
    @State private var map: Map?
    /// The GeoPackage used to create the feature layer.
    @State private var mobileMapPackage: MobileMapPackage!
    
    /// Loads a feature layer with a local GeoPackage.
    private func loadMobileMapPackage() async throws {
        // Loads the GeoPackage if it does not exist.
        if mobileMapPackage == nil {
            var yellowstoneURL: URL { Bundle.main.url(forResource: "Yellowstone", withExtension: "mmpk")! }
            mobileMapPackage = MobileMapPackage(fileURL: yellowstoneURL)
            try await mobileMapPackage.load()
            map = mobileMapPackage.maps.first
        }
    }
    
    var body: some View {
        // Creates a map view to display the map.
        if let map = map {
            MapView(map: map)
        }
    }
}
