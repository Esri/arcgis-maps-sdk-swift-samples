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

import ArcGIS
import SwiftUI

extension AddDynamicEntityLayerView {
    struct SettingsView: View {
        /// The view model for the sample.
        @ObservedObject var model: Model
        
        /// The action to dismiss the settings sheet.
        @Environment(\.dismiss) private var dismiss: DismissAction
        
        /// The callout placement.
        @Binding var calloutPlacement: CalloutPlacement?
        
        var body: some View {
            if #available(iOS 16, *) {
                NavigationStack {
                    root
                }
            } else {
                NavigationView {
                    root
                }
                .navigationViewStyle(.stack)
            }
        }
        
        @ViewBuilder var root: some View {
            Form {
                Section("Track display properties") {
                    Toggle("Track Lines", isOn: $model.showsTrackLine)
                    Toggle("Previous Observations", isOn: $model.showsPreviousObservations)
                }
                
                Section("Observations") {
                    VStack {
                        HStack {
                            Text("Observations per track")
                            Spacer()
                            Text(model.maximumObservations.formatted())
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $model.maximumObservations, in: model.maxObservationRange, step: 1)
                    }
                    HStack {
                        Spacer()
                        Button("Purge All Observations") {
                            Task {
                                try? await model.streamService.purgeAll()
                                calloutPlacement = nil
                            }
                        }
                        Spacer()
                    }
                }
            }
            .toggleStyle(.switch)
            .navigationTitle("Dynamic Entity Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
