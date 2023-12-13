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

extension DensifyAndGeneralizeGeometryView {
    struct SettingsView: View {
        /// The view model for the sample.
        @ObservedObject var model: Model
        
        var body: some View {
            List {
                // Generalize toggle and slider.
                Section {
                    Toggle("Generalize", isOn: $model.shouldGeneralize)
                        .onChange(of: model.shouldGeneralize) { _ in
                            model.updateGraphics()
                        }
                    VStack {
                        HStack {
                            Text("Max Deviation")
                            Spacer()
                            Text(String(Int(model.maxDeviation)))
                        }
                        Slider(value: $model.maxDeviation, in: 1...250)
                            .onChange(of: model.maxDeviation) { _ in
                                model.updateGraphics()
                            }
                    }
                }
                // Densify toggle and slider.
                Section {
                    Toggle("Densify", isOn: $model.shouldDensify)
                        .onChange(of: model.shouldDensify) { _ in
                            model.updateGraphics()
                        }
                    VStack {
                        HStack {
                            Text("Max Segment Length")
                            Spacer()
                            Text(String(Int(model.maxSegmentLength)))
                        }
                        Slider(value: $model.maxSegmentLength, in: 50...500)
                            .onChange(of: model.maxSegmentLength) { _ in
                                model.updateGraphics()
                            }
                    }
                }
                // Reset button that resets the model's values.
                Section {
                    Button("Reset") {
                        model.reset()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}
