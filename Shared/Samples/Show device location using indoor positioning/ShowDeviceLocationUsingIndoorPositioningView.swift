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

// "DO NOT PUSH"

struct ShowDeviceLocationUsingIndoorPositioningView: View {
    @StateObject private var model = Model()
    /// The error shown in the error alert.
    @State private var error: Error?
    
    @State private var map = Map(basemapStyle: .arcGISTopographic)
    
    var body: some View {
        MapViewReader { mapProxy in
            MapView(map: map)
                .locationDisplay(model.locationDisplay)
                .overlay(alignment: .center) {
                    if model.currentFloor > 0 {
                        if let accuracy = model.horizontalAccuracy {
                            let text = model.measurementFormatter.string(from: Measurement(value: accuracy, unit: UnitLength.meters))
                            Text("Current Floor: \(model.currentFloor) accuracy: \(text)")
                        }
                    } else {
                        Text("No floor data")
                    }
                }
                .overlay(alignment: .centerFirstTextBaseline) {
                    Text(model.source)
                }
                .overlay(alignment: .topLeading) {
                    if let sensorCount = model.sensorCount {
                        Text("Sensors \(sensorCount)")
                    } else {
                        Text("No Sensors")
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if let satelliteCount = model.satelliteCount {
                        Text("Sattelites \(satelliteCount)")
                    } else {
                        Text("No Sattelites")
                    }
                }
                .task {
                    do {
                        try await map.load()
                        try await model.setIndoorDatasource(map: map)
                    } catch {
                        self.error = error
                    }
                }
                .errorAlert(presentingError: $error)
        }
        .onAppear {
            ArcGISEnvironment.apiKey = nil
            ArcGISEnvironment.authenticationManager.arcGISAuthenticationChallengeHandler = ChallengeHandler()
            map = Map(url: URL(string: "")!)!
        }
        .onDisappear {
            ArcGISEnvironment.authenticationManager.arcGISAuthenticationChallengeHandler = nil
        }
    }
}

private struct ChallengeHandler: ArcGISAuthenticationChallengeHandler {
    func handleArcGISAuthenticationChallenge(
        _ challenge: ArcGISAuthenticationChallenge
    ) async throws -> ArcGISAuthenticationChallenge.Disposition {
        return .continueWithCredential(
            try await TokenCredential.credential(for: challenge, username: "", password: "")
        )
    }
}

#Preview {
    ShowDeviceLocationUsingIndoorPositioningView()
}
