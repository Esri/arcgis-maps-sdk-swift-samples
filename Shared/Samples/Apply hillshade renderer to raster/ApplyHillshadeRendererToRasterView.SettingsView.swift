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

extension ApplyHillshadeRendererToRasterView {
    struct SettingsView: View {
        /// The renderer that this view updates.
        @Binding var renderer: HillshadeRenderer
        /// The altitude angle of the renderer.
        @State private var altitude: Double = 0
        /// The azimuth angle of the renderer.
        @State private var azimuth: Double = 0
        /// The slope type of the renderer.
        @State private var slopeType: HillshadeRenderer.SlopeType?
        
        var body: some View {
            NavigationStack {
                Form {
                    Section {
                        LabeledContent("Altitude", value: altitude, format: .number)
                        Slider(value: $altitude, in: 0...360, step: 1)
                    }
                    Section {
                        LabeledContent("Azimuth", value: azimuth, format: .number)
                        Slider(value: $azimuth, in: 0...360, step: 1)
                    }
                    Section {
                        Picker("Slope Type", selection: $slopeType) {
                            Text("None")
                                .tag(nil as HillshadeRenderer.SlopeType?)
                            Text("Degree")
                                .tag(Optional(HillshadeRenderer.SlopeType.degree))
                            Text("Percent Rise")
                                .tag(Optional(HillshadeRenderer.SlopeType.percentRise))
                            Text("Scaled")
                                .tag(Optional(HillshadeRenderer.SlopeType.scaled))
                        }
                    }
                }
                .onAppear {
                    // Initialize the state when the view appears.
                    altitude = renderer.altitude.converted(to: .degrees).value
                    azimuth = renderer.azimuth.converted(to: .degrees).value
                    slopeType = renderer.slopeType
                }
                .onChange(of: [altitude, azimuth]) { updateRenderer(previousRenderer: renderer) }
                .onChange(of: slopeType) { updateRenderer(previousRenderer: renderer) }
                .navigationTitle("Hillshade Renderer Settings")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        
        /// Updates the renderer to the latest state.
        func updateRenderer(previousRenderer: HillshadeRenderer) {
            renderer = HillshadeRenderer(
                altitude: altitude,
                azimuth: azimuth,
                slopeType: slopeType,
                zFactor: previousRenderer.zFactor,
                pixelSizeFactor: previousRenderer.pixelSizeFactor,
                pixelSizePower: previousRenderer.pixelSizePower,
                outputBitDepth: previousRenderer.outputBitDepth
            )
        }
    }
}
