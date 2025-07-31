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

struct ControlAnnotationSublayerVisibilityView: View {
    /// The view model for the sample.
    @State private var model = Model()
    
    /// The error shown in the error alert.
    @State private var error: (any Error)?
    
    var body: some View {
        MapView(map: model.map)
            .onScaleChanged { scale in
                model.currentScale = scale
            }
            .overlay(alignment: .top) {
                Text("Current scale: \(model.currentScaleText)")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(8)
                    .background(.ultraThinMaterial, ignoresSafeAreaEdges: .horizontal)
                    .multilineTextAlignment(.center)
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Menu("Sublayers") {
                        Toggle("Closed", isOn: $model.showsClosedSublayer)
                            .onChange(of: model.showsClosedSublayer) {
                                model.setClosedSublayerVisibility(model.showsClosedSublayer)
                            }
                        Toggle(model.minMaxScaleText, isOn: $model.showsOpenSublayer)
                            .onChange(of: model.showsOpenSublayer) {
                                model.setOpenSublayerVisibility(model.showsOpenSublayer)
                            }
                            .disabled(!model.visibleAtCurrentExtent)
                    }
                }
            }
            .task {
                do {
                    try await model.loadMobileMapPackage()
                } catch {
                    self.error = error
                }
            }
            .errorAlert(presentingError: $error)
    }
}

#Preview {
    ControlAnnotationSublayerVisibilityView()
}
