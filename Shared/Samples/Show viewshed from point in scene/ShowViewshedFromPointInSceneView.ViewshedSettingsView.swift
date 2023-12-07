// Copyright 2022 Esri
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

extension ShowViewshedFromPointInSceneView {
    struct ViewshedSettingsView: View {
        /// The view model for the sample.
        @ObservedObject var model: Model
        
        var body: some View {
            List {
                Section("Visibility") {
                    Toggle("Analysis Overlay", isOn: $model.isAnalysisOverlayVisible)
                    Toggle("Frustum Outline", isOn: $model.frustumOutlineIsVisible)
                }
                
                Section("Colors") {
                    ColorPicker("Obstructed Area", selection: $model.obstructedAreaColor)
                    ColorPicker("Visible Area", selection: $model.visibleColor)
                    ColorPicker("Frustum Outline", selection: $model.frustumOutlineColor)
                }
                
                Section("Perspective") {
                    PerspectiveRow(label: "Height", measurementValue: $model.locationZ, range: 10...300, unit: UnitLength.meters)
                    PerspectiveRow(label: "Heading", measurementValue: $model.heading, range: 0...360, unit: UnitAngle.degrees)
                    PerspectiveRow(label: "Pitch", measurementValue: $model.pitch, range: 0...180, unit: UnitAngle.degrees)
                    PerspectiveRow(label: "Horizontal Angle", measurementValue: $model.horizontalAngle, range: 0...120, unit: UnitAngle.degrees)
                    PerspectiveRow(label: "Vertical Angle", measurementValue: $model.verticalAngle, range: 0...120, unit: UnitAngle.degrees)
                    PerspectiveRow(label: "Min Distance", measurementValue: $model.minDistance, range: 1...1000, unit: UnitLength.meters)
                    PerspectiveRow(label: "Max Distance", measurementValue: $model.maxDistance, range: 1000...2000, unit: UnitLength.meters)
                }
            }
        }
    }
    
    /// A slider to adjust various dimensional unit of measures.
    private struct PerspectiveRow: View {
        let label: String
        @Binding var measurementValue: Double
        let range: ClosedRange<Double>
        let unit: Dimension
        
        var body: some View {
            VStack {
                HStack {
                    Text(label)
                    Spacer()
                    Text(
                        Measurement(value: measurementValue, unit: unit),
                        format: .measurement(width: .narrow, numberFormatStyle: .number.precision(.fractionLength(0)))
                    )
                    .foregroundColor(.secondary)
                }
                Slider(value: $measurementValue, in: range)
            }
        }
    }
}
