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
import ArcGISToolkit
import SwiftUI

extension SearchForWebMapView {
    /// A map view that shows an alert when there is an error loading the map.
    struct SafeMapView: View {
        /// The map shown in the map view.
        let map: Map
        
        /// The view model that handles the errors.
        @StateObject private var errorHandler = ErrorHandler()
        
        /// A Boolean value indicating whether the map is being loaded.
        @State private var mapIsLoading = false
        
        var body: some View {
            ZStack {
                MapView(map: map)
                    .task {
                        mapIsLoading = true
                        defer { mapIsLoading = false }
                        
                        // Show an alert for an error loading the map.
                        do {
                            try await map.load()
                        } catch {
                            errorHandler.error = error
                        }
                    }
                
                if mapIsLoading {
                    ProgressView()
                }
            }
            .onAppear {
                // Update the challenger handler to get any errors thrown.
                ArcGISEnvironment.authenticationManager.arcGISAuthenticationChallengeHandler = errorHandler
            }
            .onDisappear {
                // Reset the authentication challenge handler to use default handling.
                ArcGISEnvironment.authenticationManager.arcGISAuthenticationChallengeHandler = nil
            }
            .errorAlert(presentingError: $errorHandler.error)
        }
    }
    
    /// A view that shows a given portal item's info in a row.
    struct PortalItemRowView: View {
        /// The portal item to display in the row.
        let item: PortalItem
        
        var body: some View {
            VStack {
                HStack {
                    AsyncImage(url: item.thumbnail?.url) { image in
                        image
                            .resizable()
                    } placeholder: {
                        Color(.lightGray)
                    }
                    .frame(width: 110, height: 75)
                    .border(.primary)
                    .padding([.leading, .top], 10)
                    
                    Text(item.title)
                    
                    Spacer()
                }
                
                HStack {
                    if let modificationDate = item.modificationDate {
                        Text(modificationDate, format: Date.FormatStyle(date: .abbreviated, time: .omitted))
                            .foregroundColor(Color(.systemGray5))
                    } else {
                        Text("Date: Unknown")
                            .foregroundColor(Color(.systemGray5))
                    }
                    
                    Divider()
                        .overlay(.black)
                    
                    Text(item.owner)
                        .foregroundColor(.teal)
                    
                    Spacer()
                }
                .font(.footnote)
                .padding(10)
                .background(Color(.darkGray))
            }
            .background(Color(.systemGray5))
            .border(Color(.darkGray))
            .padding(.top, 8)
            .padding(.horizontal)
        }
    }
}

private extension SearchForWebMapView.SafeMapView {
    /// A view model for handling errors.
    @MainActor
    class ErrorHandler: ArcGISAuthenticationChallengeHandler, ObservableObject {
        /// The error thrown.
        @Published var error: Error?
        
        /// Gets the error from a given authentication challenge.
        /// - Parameter challenge: The challenge that was received.
        /// - Returns: An ArcGIS authentication challenge disposition.
        func handleArcGISAuthenticationChallenge(
            _ challenge: ArcGISAuthenticationChallenge
        ) async throws -> ArcGISAuthenticationChallenge.Disposition {
            // Get the error from the challenge.
            error = challenge.error
            return .continueWithoutCredential
        }
    }
}
