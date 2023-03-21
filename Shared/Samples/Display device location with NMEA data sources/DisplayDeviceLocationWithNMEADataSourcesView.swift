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

struct DisplayDeviceLocationWithNMEADataSourcesView: View {
    /// The model used to store the geo model and other expensive objects
    /// used in this view.
    private class Model: ObservableObject {
        /// A map with imagery basemap.
        let map = Map(basemapStyle: .arcGISImagery)
    }
    
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// A Boolean value indicating whether the source sheet is being shown or not.
    @State private var shouldShowSource = false
    
    /// A Boolean value indicating whether the map should recenter.
    @State private var shouldRecenter = false
    
    /// A Boolean value indicating whether the source should be reset.
    @State private var shouldReset = false

    var body: some View {
        // Creates a map view to display the map.
        MapView(map: model.map)
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Spacer()
                    Button("Source") {
                        shouldShowSource = true
                    }
                    Spacer()
                    Button("Recenter") {
                        shouldRecenter = true
                    }
                    Spacer()
                    Button("Reset") {
                        shouldReset = true
                    }
//                    .sheet(isPresented: shouldShowSource, detents: [.medium], dragIndicatorVisibility: .visible) {
//                        ViewshedSettingsView()
//                            .environmentObject(model)
//                    }
                }
            }
    }
}
