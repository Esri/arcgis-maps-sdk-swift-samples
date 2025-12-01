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
                .popover(isPresented: $showsPopup, attachmentAnchor: .point(.bottom)) { [popup] in
                    PopupView(root: popup!, isPresented: $showsPopup)
                        .presentationDetents([.fraction(0.5)])
                        .frame(idealWidth: 320, idealHeight: 300)
                }
                .toolbar {
                    ToolbarItem(placement: .bottomBar) {
                        Button("Clustering Settings") {
                            showsSettings = true
                        }
                        .popover(isPresented: $showsSettings) {
                            settingsView
                                .frame(idealWidth: 320, idealHeight: 340)
                                .presentationCompactAdaptation(.popover)
                        }
                    }
                }
                .task {
                    await proxy.setViewpoint(Viewpoint(latitude: 47.38, longitude: 8.53, scale: 8e4))
                    try? await model.setup()
                }
        }
    }
    
    @ViewBuilder var settingsView: some View {
        NavigationStack {
            Form {
                Section("Cluster Labels Visibility") {
                    Toggle("Show Labels", isOn: $model.showsLabels)
                        .toggleStyle(.switch)
                }
                
                Section("Clustering Properties") {
                    Picker("Cluster Radius", selection: $model.radius) {
                        ForEach([30.0, 45.0, 60.0, 75.0, 90.0], id: \.self) { radius in
                            Text(radius, format: .number)
                        }
                    }
                    Picker("Cluster Max Scale", selection: $model.maxScale) {
                        ForEach([0.0, 1000.0, 5000.0, 10000.0, 50000.0, 100000.0, 500000.0], id: \.self) { scale in
                            Text(scale, format: .number)
                        }
                    }
                    LabeledContent(
                        "Current Map Scale",
                        value: mapViewScale,
                        format: .number.precision(.fractionLength(0))
                    )
                }
            }
            .navigationTitle("Clustering Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showsSettings = false
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ConfigureClustersView()
    }
}
