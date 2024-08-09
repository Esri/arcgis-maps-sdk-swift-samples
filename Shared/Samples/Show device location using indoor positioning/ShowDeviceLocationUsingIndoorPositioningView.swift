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
    /// This is the text description of the current floor that is displayed.
    @State private var currentFloorText: String = ""
    /// This is the text description of the data source that is displayed.
    @State private var sourceText: String = ""
    /// This is the text description of the number sensor of the data that is displayed.
    @State private var sensorText: String = ""
    /// This is the text description of the horizontal accuracy data that is displayed.
    @State private var accuracyText: String = ""
    
    var body: some View {
        MapView(map: model.map)
            .locationDisplay(model.locationDisplay)
            .overlay(alignment: .top) {
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading) {
                        Text(currentFloorText)
                        Text(accuracyText)
                    }
                    VStack(alignment: .leading) {
                        Text(sourceText)
                        Text(sensorText)
                    }
                }
                .frame(maxWidth: .infinity)
                .background(.white)
                .opacity(currentFloorText.isEmpty ? 0 : 0.8)
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
                    try await model.updateDisplayOnLocationChange {
                        updateStatusTextDisplay()
                    }
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
    
    /// Updates the labels on the view with the current state of the indoors data source.
    private func updateStatusTextDisplay() {
        if let currentFloor = model.currentFloor {
            currentFloorText = "Current floor: \(currentFloor)\n"
            if let horizontalAccuracy = model.horizontalAccuracy {
                let accuracyMeasurement = Measurement(value: horizontalAccuracy, unit: UnitLength.meters)
                accuracyText = "Accuracy: \(accuracyMeasurement.formatted(.measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(2)))))"
            }
            if let sensorCount = model.sensorCount {
                sensorText = "Number of sensors: \(sensorCount)\n"
            } else if let satelliteCount = model.satelliteCount, model.source == "GNSS" {
                sensorText = "Number of satellites: \(satelliteCount)\n"
            }
            sourceText = "Data source: \(model.source ?? "")"
        } else {
            currentFloorText = "No floor data."
        }
    }
}

#Preview {
    ShowDeviceLocationUsingIndoorPositioningView()
}
