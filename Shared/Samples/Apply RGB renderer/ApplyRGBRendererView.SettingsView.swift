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

extension ApplyRGBRendererView {
    struct SettingsView: View {
        /// The action to dismiss the view.
        @Environment(\.dismiss) private var dismiss
        /// A binding to the renderer settings.
        @Binding var settings: RendererSettings
        
        var body: some View {
            Form {
                Section {
                    Picker("Type", selection: $settings.stretchType) {
                        ForEach(StretchType.allCases, id: \.self) { stretchType in
                            Text(stretchType.label)
                        }
                    }
                }
                
                Section {
                    switch settings.stretchType {
                    case .histogramEqualization:
                        EmptyView()
                    case .minMax:
                        ColorPicker("Min Color", selection: $settings.minColor, supportsOpacity: false)
                        ColorPicker("Max Color", selection: $settings.maxColor, supportsOpacity: false)
                    case .percentClip:
                        HStack {
                            Text("\(Int(settings.minValue))")
                            Spacer()
                            Text("\(Int(settings.maxValue))")
                        }
                        RangeSlider(lowerValue: $settings.minValue, upperValue: $settings.maxValue, range: 0...100, step: 1)
                    case .standardDeviation:
                        LabeledContent("Factor", value: settings.standardDeviation, format: .number.precision(.fractionLength(2)))
                        Slider(value: $settings.standardDeviation, in: 0.0...16.0, step: 0.01) {
                            Text("Factor")
                        } minimumValueLabel: {
                            Text("0")
                        } maximumValueLabel: {
                            Text("16")
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
