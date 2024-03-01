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

import ArcGIS
import ArcGISToolkit
import SwiftUI

struct ConfigureClustersView: View {
    /// The model for the sample.
    @StateObject private var model = Model()
    
    /// The popup to be shown as the result of the layer identify operation.
    @State private var popup: Popup?
    
    /// A Boolean value indicating whether the popup view is shown.
    @State private var showsPopup = false
    
    /// A Boolean value indicating whether the settings view is presented.
    @State private var showsSettings = false
    
    /// The map view's scale.
    @State private var mapViewScale = 0.0
    
    var body: some View {
        MapViewReader { proxy in
            MapView(map: model.map)
                .onScaleChanged { scale in
                    mapViewScale = scale
                }
                .onSingleTapGesture { screenPoint, _ in
                    Task {
                        guard let featureLayer = model.featureLayer,
                              let result = try? await proxy.identify(on: featureLayer, screenPoint: screenPoint, tolerance: 12),
                              !result.popups.isEmpty else { return }
                        popup = result.popups.first
                        showsPopup = popup != nil
                    }
                }
                .floatingPanel(
                    selectedDetent: .constant(.half),
                    horizontalAlignment: .leading,
                    isPresented: $showsPopup
                ) { [popup] in
                    PopupView(popup: popup!, isPresented: $showsPopup)
                        .showCloseButton(true)
                        .padding()
                }
                .toolbar {
                    ToolbarItem(placement: .bottomBar) {
                        Button("Clustering Settings") {
                            showsSettings = true
                        }
                        .sheet(isPresented: $showsSettings, detents: [.medium], dragIndicatorVisibility: .visible) {
                            SettingsView(model: model, mapViewScale: mapViewScale)
                        }
                    }
                }
                .task {
                    await proxy.setViewpoint(Viewpoint(latitude: 47.38, longitude: 8.53, scale: 8e4))
                    try? await model.setup()
                }
        }
    }
}

#Preview {
    NavigationView {
        ConfigureClustersView()
    }
}
