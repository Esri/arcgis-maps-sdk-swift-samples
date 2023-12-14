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
    
    /// A Boolean value indicating whether the settings should be presented.
    @State private var isShowingSettings = false
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
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
                ToolbarItem(placement: .bottomBar) {
                    Button("Visibility Settings") {
                        isShowingSettings.toggle()
                    }
                    .sheet(isPresented: $isShowingSettings, detents: [.medium], dragIndicatorVisibility: .visible) {
                        SettingsView(model: model)
                    }
                }
            }
            .task {
                do {
                    try await model.setup()
                } catch {
                    // Presents an error message if the subtype layer fails to load.
                    self.error = error
                }
            }
            .errorAlert(presentingError: $error)
    }
}

#Preview {
    NavigationView {
        SetVisibilityOfSubtypeSublayerView()
    }
}
