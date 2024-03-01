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

extension ConfigureClustersView {
    struct SettingsView: View {
        /// The model for the sample.
        @ObservedObject var model: Model
        
        /// The action to dismiss the settings sheet.
        @Environment(\.dismiss) private var dismiss: DismissAction
        
        /// The map view's scale.
        let mapViewScale: Double
        
        /// The radius of feature clusters selected by the user.
        @State private var selectedRadius = 60
        
        /// The maximum scale of feature clusters selected by the user.
        @State private var selectedMaxScale = 0
        
        var body: some View {
            NavigationView {
                Form {
                    Section("Cluster Labels Visibility") {
                        Toggle("Show Labels", isOn: $model.showsLabels)
                            .toggleStyle(.switch)
                    }
                    
                    Section("Clustering Properties") {
                        Picker("Cluster Radius", selection: $selectedRadius) {
                            ForEach([30, 45, 60, 75, 90], id: \.self) { radius in
                                Text("\(radius)")
                            }
                        }
                        .onChange(of: selectedRadius) { newRadius in
                            model.radius = Double(newRadius)
                        }
                        
                        Picker("Cluster Max Scale", selection: $selectedMaxScale) {
                            ForEach([0, 1000, 5000, 10000, 50000, 100000, 500000], id: \.self) { scale in
                                Text(("\(scale)"))
                            }
                        }
                        .onChange(of: selectedMaxScale) { newMaxScale in
                            model.maxScale = Double(newMaxScale)
                        }
                        
                        HStack {
                            Text("Current Map Scale")
                            Spacer()
                            Text(mapViewScale, format: .number.precision(.fractionLength(0)))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .navigationTitle("Clustering Settings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
            .navigationViewStyle(.stack)
        }
    }
}
