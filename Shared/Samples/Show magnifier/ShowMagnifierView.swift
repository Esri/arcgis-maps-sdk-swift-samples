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

struct ShowMagnifierView: View {
    /// A map with a "World Topographic Map" tiled layer.
    @State private var map = Map(basemapStyle: .arcGISTopographic)
    
    /// A Boolean value indicating if the magnifier is enabled.
    @State private var magnifierIsEnabled = true
    
    var body: some View {
        MapView(map: map)
            // Enable/disable magnifier.
            .magnifierDisabled(!magnifierIsEnabled)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    // Button to toggle whether the magnifier is enabled.
                    Button {
                        magnifierIsEnabled.toggle()
                    } label: {
                        Image(
                            systemName: magnifierIsEnabled ? "magnifyingglass.circle.fill" : "magnifyingglass.circle"
                        )
                    }
                }
            }
    }
}

#Preview {
    AddTiledLayerView()
}
