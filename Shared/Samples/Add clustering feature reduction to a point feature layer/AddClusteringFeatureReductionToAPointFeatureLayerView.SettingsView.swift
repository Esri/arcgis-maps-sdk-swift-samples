// Copyright 2023 Esri
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

extension AddClusteringFeatureReductionToAPointFeatureLayerView {
    struct SettingsView: View {
        /// The model for the sample.
        @ObservedObject var model: Model
        
        /// The action to dismiss the settings sheet.
        @Environment(\.dismiss) private var dismiss: DismissAction
        
        /// The map view's scale.
        let mapViewScale: Double
        
        /// A format style to display a floating point number's integer part.
        let formatStyle: FloatingPointFormatStyle<Double> = .number.precision(.fractionLength(0))
        
        /// The maximum scale of feature clusters.
        @State private var maxScale = 0.0
        
        /// The radius of feature clusters.
        @State private var radius = 60.0
        
        var body: some View {
            settings
        }
        
        @ViewBuilder var settings: some View {
            Form {
                Section("Cluster Labels Visibility") {
                    Toggle("Show Labels", isOn: $model.showsLabels)
                }
                
                Section("Clustering Properties") {
                    VStack {
                        HStack {
                            Text("Cluster Radius")
                            Spacer()
                            Text(radius.formatted(formatStyle))
                                .foregroundColor(.secondary)
                        }
                        Slider(
                            value: $radius,
                            in: 30...85,
                            onEditingChanged: { isEditing in
                                if !isEditing {
                                    model.radius = radius
                                }
                            }
                        )
                    }
                    VStack {
                        HStack {
                            Text("Cluster Max Scale")
                            Spacer()
                            Text(maxScale.formatted(formatStyle))
                                .foregroundColor(.secondary)
                        }
                        Slider(
                            value: $maxScale,
                            in: 0...150000,
                            onEditingChanged: { isEditing in
                                if !isEditing {
                                    model.maxScale = maxScale
                                }
                            }
                        )
                    }
                    Text("Current Map Scale: \(mapViewScale.formatted(formatStyle))")
                }
            }
            .toggleStyle(.switch)
        }
    }
}
