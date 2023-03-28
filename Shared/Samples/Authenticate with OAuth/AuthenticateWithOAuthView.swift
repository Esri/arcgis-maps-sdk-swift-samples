// Copyright 2023 Esri
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

import SwiftUI
import ArcGIS
import ArcGISToolkit

struct AuthenticateWithOAuthView: View {
    /// The authenticator to handle authentication challenges.
    @StateObject private var authenticator = Authenticator(
        oAuthUserConfigurations: [.arcgisDotCom]
    )
    
    /// The map to be displayed on the map view.
    @State private var map: Map = {
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
    
    var body: some View {
        MapView(map: map)
            .authenticator(authenticator)
            .onAppear {
                // Setting the challenge handlers here in `onAppear` so user is prompted to enter
                // credentials every time trying the sample. In real world applications, set challenge
                // handlers at the start of the application.
                
                // Sets authenticator as ArcGIS and Network challenge handlers to handle authentication
                // challenges.
                ArcGISEnvironment.authenticationManager.handleChallenges(using: authenticator)
                
                // In real world applications, uncomment this code to persist credentials in the
                // keychain and remove `signOut()` from `onDisappear`.
                // setupPersistentCredentialStorage()
            }
            .onDisappear {
                // Resetting the challenge handlers and clearing credentials here in `onDisappear`
                // so user is prompted to enter credentials every time trying the sample. In real
                // world applications, do these from sign out functionality of the application.
                
                // Resets challenge handlers.
                ArcGISEnvironment.authenticationManager.handleChallenges(using: nil)

                signOut()
            }
    }
    
    /// Signs out from the portal by revoking OAuth tokens and clearing credential stores.
    func signOut() {
        Task {
            await ArcGISEnvironment.authenticationManager.revokeOAuthTokens()
            await ArcGISEnvironment.authenticationManager.clearCredentialStores()
        }
    }
    
    // Sets up new ArcGIS and Network credential stores that will be persisted in the keychain.
    func setupPersistentCredentialStorage() {
        Task {
            try await ArcGISEnvironment.authenticationManager.setupPersistentCredentialStorage(
                access: .whenUnlockedThisDeviceOnly,
                synchronizesWithiCloud: false
            )
        }
    }
}

private extension OAuthUserConfiguration {
    /// The configuration of the application registered on ArcGIS Online.
    static let arcgisDotCom = OAuthUserConfiguration(
        portalURL: .portal,
        clientID: .clientID,
        redirectURL: .redirectURL
    )
}

private extension URL {
    /// The URL of the portal to authenticate.
    /// - Note: If you want to use your own portal, provide URL here.
    static let portal = URL(string: "https://www.arcgis.com")!
    
    /// The URL for redirecting after a successful authorization.
    /// - Note: You must have the same redirect URL used here registered with your client ID.
    /// The scheme of the redirect URL is also specified in the Info.plist file.
    static let redirectURL = URL(string: "my-ags-app://auth")!
}

private extension String {
    /// A unique identifier associated with an application registered with the portal.
    /// - Note: This identifier is for a public application created by the ArcGIS Maps SDK team.
    static let clientID = "lgAdHkYZYlwwfAhC"
}

private extension PortalItem.ID {
    /// The portal item ID of a web map to be displayed on the map.
    static var trafficMap: Self { Self("e5039444ef3c48b8a8fdc9227f9be7c1")! }
}
