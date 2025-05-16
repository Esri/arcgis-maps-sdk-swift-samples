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
import ArcGISToolkit
import SwiftUI

struct AuthenticateWithTokenView: View {
    /// The authenticator to handle authentication challenges.
    @StateObject private var authenticator = Authenticator()
    
    /// A map with a traffic layer.
    @State private var map = {
        // The portal to authenticate with named user.
        let portal = Portal(url: .portal, connection: .authenticated)
        
        // The portal item to be displayed on the map.
        let portalItem = PortalItem(
            portal: portal,
            id: .trafficMap
        )
        
        // Creates map with portal item.
        return Map(item: portalItem)
    }()
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    var body: some View {
        MapView(map: map)
            .onLayerViewStateChanged { layer, layerViewState in
                guard layer.name == map.operationalLayers.first?.name else { return }
                if layerViewState.status == .error {
                    error = layer.loadError
                }
            }
            .errorAlert(presentingError: $error)
            .authenticator(authenticator)
            .onAppear {
                setupAuthenticator()
            }
            .onDisappear {
                Task {
                    // Reset the challenge handlers and clear credentials
                    // when the view disappears so that user is prompted to enter
                    // credentials every time the sample is run, and to clean
                    // the environment for other samples.
                    await teardownAuthenticator()
                }
            }
    }
}

private extension AuthenticateWithTokenView {
    /// Sets up the authenticator to handle challenges.
    func setupAuthenticator() {
        // Setting the challenge handlers here when the model is created so user is prompted to enter
        // credentials every time trying the sample. In real world applications, set challenge
        // handlers at the start of the application.
        
        // Sets authenticator as ArcGIS and Network challenge handlers to handle authentication
        // challenges.
        ArcGISEnvironment.authenticationManager.handleChallenges(using: authenticator)
        
        // In your application you may want to uncomment this code to persist
        // credentials in the keychain.
        // setupPersistentCredentialStorage()
    }
    
    /// Stops the authenticator from handling the challenges and clears credentials.
    nonisolated func teardownAuthenticator() async {
        // Resets challenge handlers.
        ArcGISEnvironment.authenticationManager.handleChallenges(using: nil)
        
        // In your application, code may need to run at a different
        // point in time based on the workflow desired. For example, it
        // might make sense to remove credentials when the user taps
        // a "sign out" button.
        await ArcGISEnvironment.authenticationManager.revokeOAuthTokens()
        await ArcGISEnvironment.authenticationManager.clearCredentialStores()
    }
    
    /// Sets up new ArcGIS and Network credential stores that will be persisted in the keychain.
    private func setupPersistentCredentialStorage() {
        Task {
            try await ArcGISEnvironment.authenticationManager.setupPersistentCredentialStorage(
                access: .whenUnlockedThisDeviceOnly,
                synchronizesWithiCloud: false
            )
        }
    }
}

private extension URL {
    /// The URL of the portal to authenticate.
    /// - Note: If you want to use your own portal, provide URL here.
    static let portal = URL(string: "https://www.arcgis.com")!
}

private extension PortalItem.ID {
    /// The portal item ID of a web map to be displayed on the map.
    static var trafficMap: Self { Self("e5039444ef3c48b8a8fdc9227f9be7c1")! }
}

#Preview {
    AuthenticateWithTokenView()
}
