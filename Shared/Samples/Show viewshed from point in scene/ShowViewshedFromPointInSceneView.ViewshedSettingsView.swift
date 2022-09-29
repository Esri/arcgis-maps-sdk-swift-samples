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
        @EnvironmentObject private var model: Model
        
        var body: some View {
            List {
                Section("Toggles") {
                    Toggle("Analysis Overlay Visible", isOn: $model.analysisOverlay.isVisible)
                    Toggle("Frustum Outline Visible", isOn: $model.viewshed.isFrustumOutlineVisible)
                }
                
                Section("Colors") {
                    ColorPicker("Obstructed Area", selection: $model.obstructedAreaColor)
                    ColorPicker("Visible Area", selection: $model.visibleColor)
                    ColorPicker("Frustum Outline", selection: $model.frustumOutlineColor)
                }
                
                Section("Perspective") {
                    MeasurementSlider<UnitLength>(label: "Height", measurementValue: $model.locationZ, range: 10...300, minValue: Measurement(value: 10, unit: .meters), maxValue: Measurement(value: 300, unit: .meters))
                    MeasurementSlider<UnitAngle>(label: "Heading", measurementValue: $model.viewshed.heading, range: 0...360, minValue: .d0, maxValue: .d360)
                    MeasurementSlider<UnitAngle>(label: "Pitch", measurementValue: $model.viewshed.pitch, range: 0...180, minValue: .d0, maxValue: .d180)
                    MeasurementSlider<UnitAngle>(label: "Horizontal Angle", measurementValue: $model.viewshed.horizontalAngle, range: 0...120, minValue: .d0, maxValue: .d120)
                    MeasurementSlider<UnitAngle>(label: "Vertical Angle", measurementValue: $model.viewshed.verticalAngle, range: 0...120, minValue: .d0, maxValue: .d120)
                    MeasurementSlider<UnitLength>(label: "Min Distance", measurementValue: Binding($model.viewshed.minDistance)!, range: 1...1000, minValue: Measurement(value: 1, unit: .meters), maxValue: Measurement(value: 1000, unit: .meters))
                    MeasurementSlider<UnitLength>(label: "Max Distance", measurementValue: Binding($model.viewshed.maxDistance)!, range: 1000...2000, minValue: Measurement(value: 1000, unit: .meters), maxValue: Measurement(value: 2000, unit: .meters))
                }
            }
        }
    }
    
    /// A slider to adjust various dimensional unit of measures.
    struct MeasurementSlider<UnitType>: View where UnitType: Dimension {
        let label: String
        @Binding var measurementValue: Double
        let range: ClosedRange<Double>
        let minValue: Measurement<UnitType>
        let maxValue: Measurement<UnitType>
        
        var body: some View {
            HStack {
                Text(label)
                    .minimumScaleFactor(0.5)
                Spacer()
                Slider(value: $measurementValue, in: range)
                    .frame(width: 160, alignment: .trailing)
            }
        }
    }
}

private extension Measurement where UnitType == UnitAngle {
    /// 0 degrees.
    static var d0: Self { Measurement(value: 0, unit: UnitAngle.degrees) }
    
    /// 120 degrees.
    static var d120: Self { Measurement(value: 120, unit: UnitAngle.degrees) }
    
    /// 180 degrees.
    static var d180: Self { Measurement(value: 180, unit: UnitAngle.degrees) }
    
    /// 360 degrees.
    static var d360: Self { Measurement(value: 360, unit: UnitAngle.degrees) }
}
