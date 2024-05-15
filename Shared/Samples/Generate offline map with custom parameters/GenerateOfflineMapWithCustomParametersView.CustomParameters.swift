// Copyright 2024 Esri
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

extension GenerateOfflineMapWithCustomParametersView {
    struct CustomParameters: View {
        /// The action to dismiss the sheet.
        @Environment(\.dismiss) private var dismiss
        
        /// The view model for the download offline map area view.
        @ObservedObject var model: Model
        
        /// The area of interest.
        let extent: Envelope
        
        /// A Boolean value indicating whether the job is generating an offline map.
        @Binding var isGeneratingOfflineMap: Bool
        
        /// The error shown in the error alert.
        @State private var error: Error?
        
        /// The min scale level for the output. Note that lower values are zoomed further out,
        /// i.e. 0 has the least detail, but one tile covers the entire Earth.
        @State private var minScaleLevel = 0.0
        
        /// The max scale level for the output. Note that higher values are zoomed further in,
        /// i.e. 23 has the most detail, but each tile covers a tiny area.
        @State private var maxScaleLevel = 23.0
        
        /// The range for scale level values.
        private let scaleLevelRange = 0.0...23.0
        
        /// The extra padding added to the extent envelope to fetch a larger area, in meters.
        @State private var basemapExtentBufferDistance = 0.0
        
        /// The range for buffering the basemap extent.
        private let basemapExtentBufferRange = 0.0...100.0
        
        /// A Boolean value indicating if the system valves layer should be included in
        /// the download.
        @State private var includeSystemValves = true
        
        /// A Boolean value indicating if the service connections layer should be included
        /// in the download.
        @State private var includeServiceConnections = true
        
        /// The minimum flow rate by which to filter features in the Hydrants layer,
        /// in gallons per minute.
        @State private var minHydrantFlowRate = 0.0
        
        /// The hydrant flow rate range.
        private let hydrantFlowRateRange = 0.0...1500.0
        
        /// A Boolean value indicating if the pipe layers should be restricted to
        /// the extent frame.
        @State private var shouldCropWaterPipesToExtent = true
        
        var body: some View {
            NavigationStack {
                Form {
                    Section(header: Text("Adjust Basemap")) {
                        HStack {
                            Text("Min Scale Level")
                            Spacer()
                            Text(minScaleLevel, format: .number.precision(.fractionLength(0)))
                        }
                        Slider(value: $minScaleLevel, in: scaleLevelRange, step: 1.0)
                        
                        HStack {
                            Text("Max Scale Level")
                            Spacer()
                            Text(maxScaleLevel, format: .number.precision(.fractionLength(0)))
                        }
                        Slider(value: $maxScaleLevel, in: scaleLevelRange, step: 1.0)
                        
                        HStack {
                            Text("Extent Buffer Distance")
                            Spacer()
                            Text(basemapExtentBufferDistance, format: .number.precision(.fractionLength(0)))
                        }
                        Slider(value: $basemapExtentBufferDistance, in: basemapExtentBufferRange)
                    }
                    
                    Section(header: Text("Include Layers")) {
                        Toggle("System Valves", isOn: $includeSystemValves)
                        Toggle("Service Connections", isOn: $includeServiceConnections)
                    }
                    
                    Section(header: Text("Filter Feature Layer")) {
                        HStack {
                            Text("Min Hydrant Flow Rate")
                            Spacer()
                            Text(minHydrantFlowRate, format: .number.precision(.fractionLength(0)))
                        }
                        Slider(value: $minHydrantFlowRate, in: hydrantFlowRateRange, step: 1.0)
                    }
                    
                    Section(header: Text("Crop Layer to Extent")) {
                        Toggle("Water Pipes", isOn: $shouldCropWaterPipesToExtent)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Start") {
                            dismiss()
                            setParameterOverridesFromUI()
                            isGeneratingOfflineMap = true
                        }
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", role: .cancel) {
                            dismiss()
                        }
                    }
                }
                .errorAlert(presentingError: $error)
                .task {
                    do {
                        // Gets the GenerateOfflineMapParameters and the
                        // GenerateOfflineMapParameterOverrides.
                        try await model.setUpParametersAndOverrides(extent: extent)
                    } catch {
                        self.error = error
                    }
                }
            }
        }
        
        /// Updates the `GenerateOfflineMapParameterOverrides` object with the user-set values.
        private func setParameterOverridesFromUI() {
            model.restrictBasemapScaleLevelRangeTo(minScaleLevel: minScaleLevel, maxScaleLevel: maxScaleLevel)
            model.bufferBasemapAreaOfInterest(by: basemapExtentBufferDistance)
            if !includeSystemValves {
                model.excludeLayer(named: "System Valve")
            }
            if !includeServiceConnections {
                model.excludeLayer(named: "Service Connection")
            }
            model.filterHydrantFlowRate(to: minHydrantFlowRate)
            model.evaluatePipeLayersExtentCropping(for: shouldCropWaterPipesToExtent)
        }
    }
}
