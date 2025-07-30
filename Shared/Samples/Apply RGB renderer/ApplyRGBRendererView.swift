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

struct ApplyRGBRendererView: View {
    /// A map with a raster layer.
    @State private var map: Map = {
        let raster = Raster(
            fileURL: Bundle.main.url(
                forResource: "Shasta",
                withExtension: "tif",
                subdirectory: "raster-file/raster-file"
            )!
        )
        return Map(basemap: Basemap(baseLayer: RasterLayer(raster: raster)))
    }()
    /// The RGB renderer settings.
    @State private var rendererSettings = RendererSettings()
    /// A Boolean value indicating whether the settings view should be presented.
    @State private var isShowingSettings = false
    /// The raster layer to apply RGB renderer.
    private var rasterLayer: RasterLayer {
        map.basemap?.baseLayers[0] as! RasterLayer
    }
    
    var body: some View {
        MapView(map: map)
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button("Stretch Parameter Settings") {
                        isShowingSettings = true
                    }
                    .popover(isPresented: $isShowingSettings) {
                        NavigationStack {
                            SettingsView(settings: $rendererSettings)
                                .onChange(of: rendererSettings, initial: true) {
                                    switch rendererSettings.stretchType {
                                    case .histogramEqualization:
                                        // Nothing to configure for histogram equalization.
                                        // It is useful when there are a lot of pixel values
                                        // that are closely grouped together
                                        setStretchParameters(HistogramEqualizationStretchParameters())
                                    case .minMax:
                                        // The pixel values which serve as endpoints for
                                        // the histogram used for the stretch.
                                        setStretchParameters(MinMaxStretchParameters(minValues: rendererSettings.minColor.rgb, maxValues: rendererSettings.maxColor.rgb))
                                    case .percentClip:
                                        // The percentile cutoff above which pixel values
                                        // in the raster dataset are to be clipped.
                                        setStretchParameters(PercentClipStretchParameters(min: rendererSettings.minValue, max: rendererSettings.maxValue))
                                    case .standardDeviation:
                                        // It applies a linear stretch between the
                                        // values defined by the standard deviation.
                                        setStretchParameters(StandardDeviationStretchParameters(factor: rendererSettings.standardDeviation))
                                    }
                                }
                        }
                        .presentationDetents([.fraction(0.5)])
                        .frame(idealWidth: 320, idealHeight: 360)
                    }
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
    
    /// The settings for a RGB renderer.
    struct RendererSettings: Equatable {
        /// The stretch type to apply to the raster layer.
        var stretchType: StretchType = .histogramEqualization
        /// The color to use for the minimum values in the min-max stretch.
        var minColor: Color = .black
        /// The color to use for the maximum values in the min-max stretch.
        var maxColor: Color = .green
        /// The minimum value for the percent clip stretch.
        var minValue: Double = 20
        /// The maximum value for the percent clip stretch.
        var maxValue: Double = 80
        /// The standard deviation factor for the standard deviation stretch.
        var standardDeviation = 0.5
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
