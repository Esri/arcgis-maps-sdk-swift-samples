//
//  ShowDeviceLocationUsingIndoorPositioningView.swift
//  Samples
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
    /// Basic map with topographic style.
    @State private var map = Map(basemapStyle: .arcGISTopographic)
    /// Represents whether the loading state is true or false.
    @State private var isLoading = false
    /// The measurement formatter for sensor accuracy.
    let measurementFormatter: MeasurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.unitStyle = .short
        formatter.unitOptions = .providedUnit
        return formatter
    }()
    
    var body: some View {
        MapView(map: map)
            .locationDisplay(model.locationDisplay)
            .overlay(alignment: .center) {
                if model.currentFloor > -1 {
                    if let accuracy = model.horizontalAccuracy,
                        let sensorCount = model.sensorCount {
                        let text = measurementFormatter.string(from: Measurement(value: accuracy, unit: UnitLength.meters))
                        Text("Current Floor: \(model.currentFloor)\nAccuracy: \(text)\nNumber of sensors \(sensorCount)\nData source: \(model.source)")
                    }
                } else {
                    Text("No floor data")
                }
            }
            .overlay(alignment: .center) {
                if isLoading {
                    ProgressView("Loading…")
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                        .shadow(radius: 50)
                }
            }
            .task {
                isLoading = true
                do {
                    try await map.load()
                    try await model.setIndoorDatasource(map: map)
                    try await model.startLocationDisplay()
                    isLoading = false
                    if let floorManager = map.floorManager {
                        try await model.updateLocation(floorManager: floorManager)
                    }
                } catch {
                    isLoading = false
                    self.error = error
                }
            }
            .errorAlert(presentingError: $error)
            .onAppear {
                ArcGISEnvironment.apiKey = nil
                ArcGISEnvironment.authenticationManager.arcGISAuthenticationChallengeHandler = ChallengeHandler()
                map = Map(url: .indoorsMap)!
            }
            .onDisappear {
                ArcGISEnvironment.authenticationManager.arcGISAuthenticationChallengeHandler = nil
            }
    }
}

private extension URL {
    static var indoorsMap: URL {
        URL(string: "")!
    }
}

private struct ChallengeHandler: ArcGISAuthenticationChallengeHandler {
    private struct Credentials {
        static let userName = ""
        static let password = ""
    }
    
    func handleArcGISAuthenticationChallenge(
        _ challenge: ArcGISAuthenticationChallenge
    ) async throws -> ArcGISAuthenticationChallenge.Disposition {
        return .continueWithCredential(
            try await TokenCredential.credential(for: challenge, username: Credentials.userName, password: Credentials.password)
        )
    }
}

#Preview {
    ShowDeviceLocationUsingIndoorPositioningView()
}
