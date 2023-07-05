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

struct SetVisibilityOfSubtypeSublayerView: View {
    /// The view model for the sample.
    @StateObject var model = Model()
    
    var body: some View {
        MapView(map: model.map)
            .onScaleChanged { scale in
                model.currentScale = scale
                model.formatCurrentScaleText()
            }
            .overlay(alignment: .top) {
                Text("Current scale: \(model.currentScaleText)")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(8)
                    .background(.ultraThinMaterial, ignoresSafeAreaEdges: .horizontal)
                    .multilineTextAlignment(.center)
            }
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button("Settings") {
                        model.isShowingSettings.toggle()
                    }
                    .sheet(isPresented: $model.isShowingSettings, detents: [.medium], dragIndicatorVisibility: .visible) {
                        SettingsView(model: model)
                    }
                }
            }
            .task {
                await model.setup()
            }
            .overlay(alignment: .top) {
                if !model.statusText.isEmpty {
                    Text(model.statusText)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(10)
                        .background(.ultraThinMaterial, ignoresSafeAreaEdges: .horizontal)
                        .multilineTextAlignment(.center)
                }
            }
    }
}
