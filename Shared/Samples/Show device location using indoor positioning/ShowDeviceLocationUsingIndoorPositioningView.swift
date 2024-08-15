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
    
    var body: some View {
        MapView(map: model.map)
            .locationDisplay(model.locationDisplay)
            .overlay(alignment: .top) {
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading) {
                        // The floor number of a location when in a building
                        // where the ground floor is 0. Negative numbers
                        // indicate floors below ground level.
                        if let floor = model.currentFloor {
                            Text("Current floor: \(floor)")
                        }
                        if let accuracy = model.horizontalAccuracy {
                            let formatStyle = Measurement<UnitLength>.FormatStyle.measurement(
                                width: .abbreviated,
                                usage: .asProvided,
                                numberFormatStyle: .number.precision(.fractionLength(2))
                            )
                            Text("Accuracy: \(Measurement<UnitLength>(value: accuracy, unit: .meters), format: formatStyle)")
                        }
                    }
                    .opacity(model.currentFloor != nil ? 1 : 0)
                    VStack(alignment: .leading) {
                        let sourceType = model.positionSource == "GNSS" ? "Satellites" : "Transmitters"
                        Text("Data source: \(model.positionSource ?? "None")")
                        Text("Number of \(sourceType): \(model.signalSourceCount ?? 0)")
                    }
                }
                .frame(maxWidth: .infinity)
                .background(.thinMaterial, ignoresSafeAreaEdges: .horizontal)
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
                // Requests location permission if it has not yet been determined.
                let locationManager = CLLocationManager()
                if locationManager.authorizationStatus == .notDetermined {
                    locationManager.requestWhenInUseAuthorization()
                }
                do {
                    try await model.loadIndoorData()
                } catch {
                    self.error = error
                }
                // Starts to receive updates from the location data source.
                await model.updateDisplayOnLocationChange()
            }
            .onDisappear {
                Task {
                    await model.locationDisplay.dataSource.stop()
                }
            }
            .errorAlert(presentingError: $error)
    }
}

#Preview {
    ShowDeviceLocationUsingIndoorPositioningView()
}
