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
    /// Represents whether the loading state is true or false.
    @State private var isLoading = false
    /// Represents the data model being used.
    @State private var dataSourceType: DataSourceType = .indoorDefinition
    
    var body: some View {
        MapView(map: model.map)
            .onDrawStatusChanged { drawStatus in
                // Updates the state when the map's draw status changes.
                if drawStatus == .completed {
                    isLoading = false
                }
            }
            .locationDisplay(model.locationDisplay)
            .overlay(alignment: .top) {
                VStack(spacing: 2) {
                    Spacer()
                    Text(model.labelText)
                    Spacer()
                    Spacer()
                    Spacer()
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
                    try await model.map.load()
                    try await model.loadAndDisplayIndoorData(for: dataSourceType)
                } catch {
                    self.error = error
                }
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Picker("Data Source Type", selection: $dataSourceType) {
                        ForEach(DataSourceType.allCases, id: \.self) { type in
                            Text(type.label)
                        }
                    }
                    .task(id: dataSourceType) {
                        Task {
                            isLoading = true
                            do {
                                try await model.loadAndDisplayIndoorData(for: dataSourceType)
                            } catch {
                                self.error = error
                            }
                        }
                    }
                }
            }
            .errorAlert(presentingError: $error)
            .onAppear {
                ArcGISEnvironment.apiKey = nil
                ArcGISEnvironment.authenticationManager.arcGISAuthenticationChallengeHandler = ChallengeHandler()
                model.map = Map(url: .indoorsMap)!
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
    enum Credentials {
        static let userName = ""
        static let password = ""
    }
    
    func handleArcGISAuthenticationChallenge(_ challenge: ArcGISAuthenticationChallenge) async throws -> ArcGISAuthenticationChallenge.Disposition {
        return .continueWithCredential(
            try await TokenCredential.credential(
                for: challenge,
                username: Credentials.userName,
                password: Credentials.password
            )
        )
    }
}

#Preview {
    ShowDeviceLocationUsingIndoorPositioningView()
}
