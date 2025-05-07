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
        
        /// The raster layer to apply the RGB renderer to.
        let rasterLayer: RasterLayer
        
        /// The stretch type to apply to the raster layer.
        @Binding var stretchType: StretchType
        /// The color to use for the minimum values in the min-max stretch.
        @State private var minColor: Color = .black
        /// The color to use for the maximum values in the min-max stretch.
        @State private var maxColor: Color = .green
        /// The minimum value for the percent clip stretch.
        @State private var minValue: Double = 20
        /// The maximum value for the percent clip stretch.
        @State private var maxValue: Double = 80
        /// The standard deviation factor for the standard deviation stretch.
        @State private var standardDeviation = 0.5
        
        var body: some View {
            Form {
                Section {
                    Picker("Type", selection: $stretchType) {
                        ForEach(StretchType.allCases, id: \.self) { stretchType in
                            Text(stretchType.label)
                        }
                    }
                    .onChange(of: stretchType, initial: true) {
                        switch stretchType {
                        case .histogramEqualization:
                            // Nothing to configure for histogram equalization.
                            // It is useful when there are a lot of pixel values
                            // that are closely grouped together
                            setStretchParameters(HistogramEqualizationStretchParameters())
                        default:
                            break
                        }
                    }
                }
                
                Section {
                    switch stretchType {
                    case .histogramEqualization:
                        EmptyView()
                    case .minMax:
                        ColorPicker("Min Color", selection: $minColor, supportsOpacity: false)
                            .onChange(of: minColor, initial: true) {
                                setStretchParameters(MinMaxStretchParameters(minValues: minColor.rgb, maxValues: maxColor.rgb))
                            }
                        ColorPicker("Max Color", selection: $maxColor, supportsOpacity: false)
                            .onChange(of: maxColor) {
                                // The pixel values which serve as endpoint for
                                // the histogram used for the stretch.
                                setStretchParameters(MinMaxStretchParameters(minValues: minColor.rgb, maxValues: maxColor.rgb))
                            }
                    case .percentClip:
                        HStack {
                            Text("\(Int(minValue))")
                            Spacer()
                            Text("\(Int(maxValue))")
                        }
                        RangeSlider(lowerValue: $minValue, upperValue: $maxValue, range: 0...100, step: 1)
                            .onChange(of: [minValue, maxValue], initial: true) {
                                // The percentile cutoff above which pixel values
                                // in the raster dataset are to be clipped.
                                setStretchParameters(PercentClipStretchParameters(min: minValue, max: maxValue))
                            }
                    case .standardDeviation:
                        Text("Factor: \(standardDeviation, format: .number.precision(.fractionLength(2)))")
                        Slider(value: $standardDeviation, in: 0.0...16.0, step: 0.01) {
                            Text("Factor")
                        } minimumValueLabel: {
                            Text("0")
                        } maximumValueLabel: {
                            Text("16")
                        }
                        .onChange(of: standardDeviation, initial: true) {
                            // It applies a linear stretch between the
                            // values defined by the standard deviation.
                            setStretchParameters(StandardDeviationStretchParameters(factor: standardDeviation))
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
        
        /// Sets the stretch parameters for the raster layer.
        /// - Parameter parameters: The stretch parameters to apply.
        private func setStretchParameters(_ parameters: StretchParameters) {
            rasterLayer.renderer = RGBRenderer(
                stretchParameters: parameters,
                bandIndexes: [],
                gammas: [],
                estimatesStatistics: true
            )
        }
    }
    
    enum StretchType: CaseIterable {
        case histogramEqualization, minMax, percentClip, standardDeviation
        
        /// The label for the stretch type.
        var label: String {
            switch self {
            case .histogramEqualization: "Histogram Equalization"
            case .minMax: "Min-Max"
            case .percentClip: "Percent Clip"
            case .standardDeviation: "Standard Deviation"
            }
        }
    }
}

private extension Color {
    /// The RGB components of the color.
    var rgb: [Double] {
        UIColor(self)
            .cgColor
            .components!
            .prefix(3)
            .map { Double($0) * 255 }
    }
}
