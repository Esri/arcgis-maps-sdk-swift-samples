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
    /// The building group sublayer toggle which has a toggle for the visibility of the group
    /// and each of its sublayers.
    struct BuildingGroupSublayerToggleView: View {
        /// The group sublayer which is used to build this view.
        let groupSublayer: BuildingGroupSublayer
        
        /// A Boolean value indicating if the group sublayer is visible.
        @State private var isVisible = true
        
        var body: some View {
            DisclosureGroup {
                ForEach(groupSublayer.sublayers) { sublayer in
                    BuildingSublayerToggleView(sublayer: sublayer)
                        // If the group sublayer isn't visible then the toggles
                        // for its sublayers should be disabled.
                        .disabled(!isVisible)
                }
            } label: {
                Toggle(groupSublayer.name, isOn: $isVisible)
                    .onChange(of: isVisible) {
                        groupSublayer.isVisible = isVisible
                    }
            }
            .onAppear {
                // Sets the value of the toggle to the
                // current visibility of the group sublayer.
                isVisible = groupSublayer.isVisible
            }
        }
    }
}
