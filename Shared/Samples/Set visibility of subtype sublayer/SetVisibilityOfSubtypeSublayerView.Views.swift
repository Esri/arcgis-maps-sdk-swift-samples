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
        @EnvironmentObject private var model: Model
        
        var body: some View {
            List {
                Section("Layers") {
                    Toggle("Show Sublayer", isOn: $model.showsSublayer)
                        .onChange(of: model.showsSublayer) { _ in
                            model.toggleSublayer()
                        }
                    Toggle("Show Original Renderer", isOn: $model.showsOriginalRenderer)
                        .onChange(of: model.showsOriginalRenderer) { _ in
                            model.toggleRenderer()
                        }
                }
                Section("Sublayer Minimum Scale") {
                    VStack {
                        HStack {
                            Text("Minimum Scale")
                            Spacer()
                            Text(model.minimumScaleText)
                                .foregroundColor(.secondary)
                        }
                    }
                    HStack {
                        Spacer()
                        Button("Set Current to Minimum Scale") {
                            model.setMinimumScale()
                        }
                        Spacer()
                    }
                }
            }
        }
    }
}
