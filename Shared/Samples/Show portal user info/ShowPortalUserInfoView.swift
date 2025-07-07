// Copyright 2025 Esri
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

struct ShowPortalUserInfoView: View {
    /// The error shown in the error alert.
    @State private var error: Error?
    @State private var map = Map()
    var body: some View {
        MapView(map: map)
            .errorAlert(presentingError: $error)
            .onAppear {
                // Updates the URL session challenge handler to use the
                // specified credentials and tokens for any challenges.
                ArcGISEnvironment.authenticationManager.arcGISAuthenticationChallengeHandler = ChallengeHandler()
            }
            .onDisappear {
                // Resets the URL session challenge handler to use default handling.
                ArcGISEnvironment.authenticationManager.arcGISAuthenticationChallengeHandler = nil
            }
    }
}

private extension ShowPortalUserInfoView {
    /// The authentication model used to handle challenges and credentials.
    private struct ChallengeHandler: ArcGISAuthenticationChallengeHandler {
        func handleArcGISAuthenticationChallenge(
            _ challenge: ArcGISAuthenticationChallenge
        ) async throws -> ArcGISAuthenticationChallenge.Disposition {
            // NOTE: Never hardcode login information in a production application.
            // This is done solely for the sake of the sample.
            return .continueWithCredential(
                try await TokenCredential.credential(for: challenge, username: "username", password: "password")
            )
        }
    }
}

#Preview {
    ShowPortalUserInfoView()
}
