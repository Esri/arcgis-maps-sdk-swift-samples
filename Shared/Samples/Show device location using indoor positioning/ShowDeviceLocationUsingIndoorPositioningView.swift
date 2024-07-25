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
                VStack(spacing: 2) {
                    HStack {
                        Text(model.labelTextLeading)
                            .frame(width: 140)
                            .multilineTextAlignment(.leading)
                        Text(model.labelTextTrailing)
                    }
                    .frame(maxWidth: .infinity)
                    .background(.white)
                    .opacity(model.labelTextLeading.isEmpty ? 0 : 0.5)
                    Spacer()
                    Spacer()
                    Spacer()
                }
            }
            .overlay(alignment: .center) {
                if model.isLoading {
                    ProgressView("Loading indoor data…")
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                        .shadow(radius: 50)
                }
            }
            .task {
                model.isLoading = true
                do {
                    try await model.map.load()
                    try await model.displayIndoorData()
                    // Since the method dataChangesOnLocationUpdate listens for new location changes, it is important
                    // to ensure any blocking UI is dismissed before it is called.
                    model.isLoading = false
                    try await model.updateAndDisplayOnLocationChange()
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
