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

struct ApplyBlendRendererToHillshadeView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// A Boolean value indicating whether the settings view should be presented.
    @State private var isShowingSettings = false
    
    var body: some View {
        MapView(map: model.map)
            .task {
                model.applyRendererSettings()
            }
            .task(id: model.altitude) {
                model.applyRendererSettings()
            }
            .task(id: model.azimuth) {
                model.applyRendererSettings()
            }
            .task(id: model.colorRampPreset) {
                model.applyRendererSettings()
            }
            .task(id: model.slopeType) {
                model.applyRendererSettings()
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button("Renderer Settings") {
                        isShowingSettings = true
                    }
                    .popover(isPresented: $isShowingSettings) {
                        SettingsView(model: model)
                            .presentationDetents([.fraction(0.5)])
                            .frame(idealWidth: 320, idealHeight: 320)
                    }
                }
            }
    }
}
