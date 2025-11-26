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

extension FilterBuildingSceneLayerView {
    /// The building sublayer toggle which is used to build a toggle view for
    /// each sublayer in a building group sublayer.
    struct BuildingSublayerToggleView: View {
        /// A Boolean value indicating if the sublayer is visible.
        @State private var isVisible: Bool
        
        /// The sublayer used to build this view.
        let sublayer: BuildingSublayer
        
        /// Creates a building sublayer view using the sublayer.
        /// - Parameter sublayer: The sublayer to help build this view.
        init(sublayer: BuildingSublayer) {
            // Sets the initial value of the toggle to the
            // current visbility of the sublayer.
            isVisible = sublayer.isVisible
            self.sublayer = sublayer
        }
        
        var body: some View {
            Toggle(sublayer.name, isOn: $isVisible)
                .onChange(of: isVisible) {
                    sublayer.isVisible = isVisible
                }
        }
    }
}
