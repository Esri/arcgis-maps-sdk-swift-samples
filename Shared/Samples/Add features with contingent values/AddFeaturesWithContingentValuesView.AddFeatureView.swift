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

extension AddFeaturesWithContingentValuesView {
    /// A view allowing the user to add a feature to the map.
    struct AddFeatureView: View {
        /// The view model for the sample.
        @ObservedObject var model: Model
        
        /// The name of the selected status.
        @State private var selectedStatusName: String?
        
        /// The coded value options for the feature's status attribute.
        @State private var statusOptions: [CodedValue?] = []
        
        /// The name of the selected protection.
        @State private var selectedProtectionName: String?
        
        /// The contingent coded value options for the feature's protection attribute.
        @State private var protectionOptions: [ContingentCodedValue?] = [] {
            didSet { selectedProtectionName = nil }
        }
        
        /// The selected exclusion area buffer size.
        @State private var selectedBufferSize: Double?
        
        /// The range of size options for the feature's buffer size attribute.
        @State private var bufferSizeRange: ClosedRange<Double>? {
            didSet { selectedBufferSize = bufferSizeRange?.lowerBound ?? 0 }
        }
        
        var body: some View {
            List {
                Section {
                    Picker("Status", selection: $selectedStatusName) {
                        ForEach(statusOptions, id: \.?.name) { option in
                            Text(option?.name ?? "")
                        }
                    }
                    .onChange(of: selectedStatusName) { newStatusName in
                        // Update the feature's status attribute.
                        guard let selectedCodedValue = statusOptions.first(
                            where: { $0?.name == newStatusName }
                        ) else { return }
                        
                        model.setFeatureAttributeValue(selectedCodedValue?.code, forKey: "Status")
                        
                        // Update the protection options.
                        protectionOptions = model.protectionContingentCodedValues()
                        
                        // Add nil to allow for an empty option in the picker.
                        protectionOptions.insert(nil, at: 0)
                    }
                    
                    Picker("Protection", selection: $selectedProtectionName) {
                        ForEach(protectionOptions, id: \.?.codedValue.name) { option in
                            Text(option?.codedValue.name ?? "")
                        }
                    }
                    .onChange(of: selectedProtectionName) { newProtectionName in
                        // Update the feature's protection attribute.
                        guard let selectedContingentValue = protectionOptions.first(
                            where: { $0?.codedValue.name == newProtectionName }
                        ) else { return }
                        
                        model.setFeatureAttributeValue(
                            selectedContingentValue?.codedValue.code,
                            forKey: "Protection"
                        )
                        
                        // Update the buffer size range.
                        bufferSizeRange = model.bufferSizeRange()
                    }
                    
                    VStack {
                        HStack {
                            Text("Exclusion Area Buffer Size")
                            Spacer()
                            Text("\(Int(selectedBufferSize ?? 0))")
                        }
                        
                        Slider(
                            value: Binding(
                                get: { selectedBufferSize ?? 0 },
                                set: { selectedBufferSize = $0 }
                            ),
                            in: bufferSizeRange ?? 0...0)
                        .onChange(of: selectedBufferSize ?? .nan) { newBufferSize in
                            guard newBufferSize.isFinite else { return }
                            
                            // Update the feature's buffer size attribute.
                            model.setFeatureAttributeValue(
                                Int32(newBufferSize),
                                forKey: "BufferSize"
                            )
                        }
                        .disabled(bufferSizeRange == nil)
                    }
                } header: {
                    Text("Set the attributes")
                } footer: {
                    Text("The options will vary depending on which values are selected.")
                }
            }
            .onAppear {
                // Get the status coded values when the view appears.
                statusOptions = model.statusCodedValues()
                
                // Add nil to allow for an empty option in the picker.
                statusOptions.insert(nil, at: 0)
            }
        }
    }
}
