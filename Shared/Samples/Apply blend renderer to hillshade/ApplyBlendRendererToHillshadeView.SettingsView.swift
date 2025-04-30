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

extension ApplyBlendRendererToHillshadeView {
    struct SettingsView: View {
        /// The action to dismiss the view.
        @Environment(\.dismiss) private var dismiss
        
        /// The view model for the sample.
        @ObservedObject var model: ApplyBlendRendererToHillshadeView.Model
        
        var body: some View {
            NavigationStack {
                Form {
                    Picker("Slope Type", selection: $model.slopeType) {
                        Text("Degree").tag(HillshadeRenderer.SlopeType.degree)
                        Text("Percent Rise").tag(HillshadeRenderer.SlopeType.percentRise)
                        Text("Scaled").tag(HillshadeRenderer.SlopeType.scaled)
                    }
                    
                    Picker("Color Ramp Preset", selection: $model.colorRampPreset) {
                        Text("DEM Light").tag(ColorRamp.Preset.demLight)
                        Text("Screen Display").tag(ColorRamp.Preset.demScreen)
                        Text("Elevation").tag(ColorRamp.Preset.elevation)
                    }
                    
                    VStack {
                        LabeledContent(
                            "Altitude",
                            value: model.altitude,
                            format: .number
                        )
                        Slider(value: $model.altitude, in: 0...360, step: 1.0) {
                            Text("Altitude")
                        } minimumValueLabel: {
                            Text("0")
                        } maximumValueLabel: {
                            Text("360")
                        }
                    }
                    
                    VStack {
                        LabeledContent(
                            "Azimuth",
                            value: model.azimuth,
                            format: .number
                        )
                        Slider(value: $model.azimuth, in: 0...360, step: 1.0) {
                            Text("Azimuth")
                        } minimumValueLabel: {
                            Text("0")
                        } maximumValueLabel: {
                            Text("360")
                        }
                    }
                }
                .navigationTitle("Renderer Settings")
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
}
