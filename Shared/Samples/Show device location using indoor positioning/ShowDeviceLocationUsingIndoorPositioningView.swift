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
import CoreLocation
import SwiftUI

struct ShowDeviceLocationUsingIndoorPositioningView: View {
    /// The data model for the sample.
    @StateObject private var model = Model()
    /// The error shown in the error alert.
    @State private var error: Error?
    /// The value of the current floor with -1 being used to represent floor that has not been set.
    @State private(set) var currentFloor: Int?
    /// The number of BLE sensors which are being used for indoor location.
    @State private(set) var sensorCount: Int?
    /// The number of satellites which are being used for the GPS location.
    @State private(set) var satelliteCount: Int?
    /// The value of the horizontal accuracy of the location (in meters).
    @State private(set) var horizontalAccuracy: Double?
    
    var body: some View {
        MapView(map: model.map)
            .locationDisplay(model.locationDisplay)
            .overlay(alignment: .top) {
                HStack(alignment: .center, spacing: 10) {
                    Text(model.labelTextLeading)
                    Text(model.labelTextTrailing)
                }
                .frame(maxWidth: .infinity)
                .background(.white)
                .opacity(model.labelTextLeading.isEmpty ? 0 : 0.8)
            }
            .overlay(alignment: .center) {
                if model.isLoading {
                    ProgressView(
                        """
                        Loading
                        indoor data…
                        """
                    )
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
                    .shadow(radius: 50)
                    .multilineTextAlignment(.center)
                }
            }
            .task {
                do {
                    try await requestLocationServicesAuthorizationIfNecessary()
                    try await model.loadIndoorData()
                    try await model.updateDisplayOnLocationChange()
                } catch {
                    self.error = error
                }
            }
            .onDisappear {
                Task {
                    await model.locationDisplay.dataSource.stop()
                }
            }
            .errorAlert(presentingError: $error)
    }
    
    /// Starts the location display to show user's location on the map.
    private func requestLocationServicesAuthorizationIfNecessary() async throws {
        /// The location manager which handles the location data.
        let locationManager = CLLocationManager()
        // Requests location permission if it has not yet been determined.
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
    }
}

#Preview {
    ShowDeviceLocationUsingIndoorPositioningView()
}
