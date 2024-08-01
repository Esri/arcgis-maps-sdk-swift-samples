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

extension ChangeMapViewBackgroundView {
    struct SettingsView: View {
        /// The view model for the sample.
        @ObservedObject var model: Model
        
        /// The action to dismiss the view.
        @Environment(\.dismiss) private var dismiss
        
        var body: some View {
            List {
                Section("Background Grid") {
                    ColorPicker("Color", selection: $model.color)
                    ColorPicker("Line Color", selection: $model.lineColor)
                    VStack {
                        LabeledContent("Line Width", value: model.lineWidth.formatted())
                        Slider(value: $model.lineWidth, in: model.lineWidthRange, step: 1)
                    }
                    VStack {
                        LabeledContent("Grid Size", value: model.size.formatted())
                        Slider(value: $model.size, in: model.sizeRange, step: 1)
                    }
                }
            }
            .navigationTitle("Background Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
