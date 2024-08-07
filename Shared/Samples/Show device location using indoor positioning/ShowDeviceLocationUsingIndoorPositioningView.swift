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
    
    /// This is the published value of the data that is displayed.
    @State private var labelTextLeading: String = ""
    
    /// This is the published value of the data that is displayed.
    @State private var labelTextTrailing: String = ""
    
    var body: some View {
        MapView(map: model.map)
            .locationDisplay(model.locationDisplay)
            .overlay(alignment: .top) {
                HStack(alignment: .center, spacing: 10) {
                    Text(labelTextLeading)
                    Text(labelTextTrailing)
                }
                .frame(maxWidth: .infinity)
                .background(.white)
                .opacity(labelTextLeading.isEmpty ? 0 : 0.8)
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
                        updateStatusText()
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
    private func updateStatusText() {
        labelTextLeading = ""
        labelTextTrailing = ""
        if let currentFloor = model.currentFloor {
            labelTextLeading += "Current floor: \(currentFloor)\n"
            if let horizontalAccuracy = model.horizontalAccuracy {
                let horizontalAccuracyMeasurement = Measurement<UnitLength>(value: horizontalAccuracy, unit: .meters)
                labelTextLeading += "Accuracy: \(horizontalAccuracyMeasurement.formatted(.distance))"
            }
            if let sensorCount = model.sensorCount {
                labelTextTrailing += "Number of sensors: \(sensorCount)\n"
            } else if let satelliteCount = model.satelliteCount, model.source == "GNSS" {
                labelTextTrailing += "Number of satellites: \(satelliteCount)\n"
            }
            labelTextTrailing += "Data source: \(model.source ?? "")"
        } else {
            labelTextLeading = "No floor data."
        }
    }
}

private extension FormatStyle where Self == Measurement<UnitLength>.FormatStyle {
    /// The format style for the distances.
    static var distance: Self {
        .measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(2)))
    }
}

#Preview {
    ShowDeviceLocationUsingIndoorPositioningView()
}
