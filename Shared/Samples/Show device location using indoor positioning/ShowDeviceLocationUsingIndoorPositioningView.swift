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

struct ShowDeviceLocationUsingIndoorPositioningView: View {
    /// The data model for the sample.
    @StateObject private var model = Model()
    /// The error shown in the error alert.
    @State private var error: Error?
    
    var body: some View {
        MapView(map: model.map)
            .locationDisplay(model.locationDisplay)
            .overlay(alignment: .top) {
                HStack {
                    Text(model.labelTextLeading)
                        .frame(width: 140)
                        .multilineTextAlignment(.leading)
                    Text(model.labelTextTrailing)
                }
                .frame(maxWidth: .infinity, maxHeight: 60)
                .background(.white)
                .opacity(model.labelTextLeading.isEmpty ? 0 : 0.5)
            }
            .overlay(alignment: .center) {
                if model.isLoading {
                    ProgressView("Loading\n indoor data…")
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                        .shadow(radius: 50)
                        .multilineTextAlignment(.center)
                }
            }
            .task {
                do {
                    try await model.loadIndoorData()
                    try await model.updateDisplayOnLocationChange()
                } catch {
                    model.isLoading = false
                    self.error = error
                }
            }
            .onDisappear {
                model.stopLocationDataSource()
            }
            .errorAlert(presentingError: $error)
    }
}

#Preview {
    ShowDeviceLocationUsingIndoorPositioningView()
}
