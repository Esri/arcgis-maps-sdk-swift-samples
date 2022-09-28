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

import ArcGIS
import SwiftUI

extension ShowViewshedFromPointInSceneView {
    struct ViewshedSettingsView: View {
        /// The view model for the download preplanned map area view.
        @EnvironmentObject private var model: Model
        
        /// The color which non-visible areas of all viewsheds will be rendered.
        @State private var obstructedAreaColor = Color(uiColor: Viewshed.obstructedColor) {
            didSet {
                Viewshed.obstructedColor = UIColor(obstructedAreaColor)
            }
        }
        
        /// The color which visible areas of all viewsheds will be rendered.
        @State private var visibleColor = Color(uiColor: Viewshed.visibleColor) {
            didSet {
                Viewshed.visibleColor = UIColor(visibleColor)
            }
        }
        
        /// The color used to render the frustum outline.
        @State private var frustumOutlineColor = Color(uiColor: Viewshed.frustumOutlineColor) {
            didSet {
                Viewshed.frustumOutlineColor = UIColor(frustumOutlineColor)
            }
        }
        
        var body: some View {
            NavigationView {
                List {
                    Section("Toggles") {
                        Toggle("Analysis Overlay Visible", isOn: $model.analysisOverlay.isVisible)
                        Toggle("Frustum Outline Visible", isOn: $model.viewshed.isFrustumOutlineVisible)
                    }
                    
                    Section("Colors") {
                        ColorPicker("Obstructed Area", selection: $obstructedAreaColor)
                        ColorPicker("Visible Area", selection: $visibleColor)
                        ColorPicker("Frustum Outline", selection: $frustumOutlineColor)
                    }
                    
                    Section("Perspective") {
                        MeasurementSlider<UnitAngle>(label: "Heading", value: $model.viewshed.heading, range: 0...360, minValue: .d0, maxValue: .d360)
                        MeasurementSlider<UnitAngle>(label: "Pitch", value: $model.viewshed.pitch, range: 0...180, minValue: .d0, maxValue: .d180)
                        MeasurementSlider<UnitAngle>(label: "Horizontal Angle", value: $model.viewshed.horizontalAngle, range: 0...120, minValue: .d0, maxValue: .d120)
                        MeasurementSlider<UnitAngle>(label: "Vertical Angle", value: $model.viewshed.verticalAngle, range: 0...120, minValue: .d0, maxValue: .d120)
                        MeasurementSlider<UnitLength>(label: "Heading", value: $model.viewshed.heading, range: 1...1000, minValue: Measurement(value: 1, unit: UnitLength.meters), maxValue: Measurement(value: 1000, unit: UnitLength.meters))
                        MeasurementSlider<UnitLength>(label: "Heading", value: $model.viewshed.heading, range: 1000...2000, minValue: Measurement(value: 1000, unit: UnitLength.meters), maxValue: Measurement(value: 2000, unit: UnitLength.meters))
                    }
                }
            }
        }
        
        /// A slider to adjust various dimensional unit of measures.
        struct MeasurementSlider<UnitType>: View where UnitType: Dimension {
            let label: String
            @Binding var value: Double
            let range: ClosedRange<Double>
            let minValue: Measurement<UnitType>
            let maxValue: Measurement<UnitType>
            
            var body: some View {
                HStack {
                    Text("\(label): \(Measurement(value: value, unit: minValue.unit), format: .measurement(width: .narrow))")
                    Slider(value: $value, in: range) {
                        Text(label)
                    } minimumValueLabel: {
                        Text(minValue, format: .measurement(width: .narrow))
                    } maximumValueLabel: {
                        Text(maxValue, format: .measurement(width: .narrow))
                    }
                }
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
