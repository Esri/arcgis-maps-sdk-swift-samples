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
        
        /// A binding to the renderer settings.
        @Binding var settings: ApplyBlendRendererToHillshadeView.RendererSettings
        
        var body: some View {
            NavigationStack {
                Form {
                    Picker("Slope Type", selection: $settings.slopeType) {
                        Text("Degree").tag(HillshadeRenderer.SlopeType.degree)
                        Text("Percent Rise").tag(HillshadeRenderer.SlopeType.percentRise)
                        Text("Scaled").tag(HillshadeRenderer.SlopeType.scaled)
                        Text("None").tag(Optional<HillshadeRenderer.SlopeType>.none)
                    }
                    
                    Picker("Color Ramp Preset", selection: $settings.colorRampPreset) {
                        Text("DEM Light").tag(ColorRamp.Preset.demLight)
                        Text("Screen Display").tag(ColorRamp.Preset.demScreen)
                        Text("Elevation").tag(ColorRamp.Preset.elevation)
                        Text("None").tag(Optional<ColorRamp.Preset>.none)
                    }
                    
                    VStack {
                        LabeledContent(
                            "Altitude",
                            value: Measurement<UnitAngle>(value: settings.altitude, unit: .degrees),
                            format: .measurement(width: .narrow)
                        )
                        Slider(value: $settings.altitude, in: 0...360, step: 1.0) {
                            Text("Altitude")
                        } minimumValueLabel: {
                            Text(Measurement<UnitAngle>(value: 0, unit: .degrees), format: .measurement(width: .narrow))
                        } maximumValueLabel: {
                            Text(Measurement<UnitAngle>(value: 360, unit: .degrees), format: .measurement(width: .narrow))
                        }
                    }
                    
                    VStack {
                        LabeledContent(
                            "Azimuth",
                            value: Measurement<UnitAngle>(value: settings.azimuth, unit: .degrees),
                            format: .measurement(width: .narrow)
                        )
                        Slider(value: $settings.azimuth, in: 0...360, step: 1.0) {
                            Text("Azimuth")
                        } minimumValueLabel: {
                            Text(Measurement<UnitAngle>(value: 0, unit: .degrees), format: .measurement(width: .narrow))
                        } maximumValueLabel: {
                            Text(Measurement<UnitAngle>(value: 360, unit: .degrees), format: .measurement(width: .narrow))
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
