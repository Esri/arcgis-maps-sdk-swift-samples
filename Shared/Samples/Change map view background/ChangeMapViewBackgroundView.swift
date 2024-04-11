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

import SwiftUI
import ArcGIS

struct ChangeMapViewBackgroundView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// A Boolean value indicating whether the settings view should be presented.
    @State private var isShowingSettings = false
    
    var body: some View {
        // Creates a map view to display the map.
        MapView(map: model.map)
            .backgroundGrid(model.backgroundGrid)
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button("Background Grid Settings") {
                        isShowingSettings = true
                    }
                    .sheet(isPresented: $isShowingSettings, detents: [.medium], dragIndicatorVisibility: .visible) {
                        SettingsView(model: model)
                    }
                }
            }
    }
}

#Preview {
    NavigationView {
        ChangeMapViewBackgroundView()
    }
}
