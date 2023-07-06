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

extension SetVisibilityOfSubtypeSublayerView {
    struct SettingsView: View {
        /// The view model for the sample.
        @ObservedObject var model: Model
        
        /// A Boolean value indicating whether to show the subtype sublayer.
        @State private var showsSublayer = true
        
        /// A Boolean value indicating whether to show the subtype sublayer's renderer.
        @State private var showsOriginalRenderer = true
        
        var body: some View {
            Form {
                Section("Layers") {
                    Toggle("Show Sublayer", isOn: $showsSublayer)
                        .onChange(of: showsSublayer) { newValue in
                            model.toggleSublayer(isVisible: newValue)
                        }
                    Toggle("Show Original Renderer", isOn: $showsOriginalRenderer)
                        .onChange(of: showsOriginalRenderer) { newValue in
                            model.toggleRenderer(showsOriginalRenderer: newValue)
                        }
                }
                Section("Sublayer Minimum Scale") {
                    HStack {
                        Text("Minimum Scale")
                        Spacer()
                        Text(model.minimumScaleText)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Button("Set Current to Minimum Scale") {
                            model.setMinimumScale()
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
        }
    }
}
