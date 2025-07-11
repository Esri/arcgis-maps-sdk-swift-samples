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

struct ShowPortalUserInfoView: View {
    @State private var model = Model()
    /// The error shown in the error alert.
    @State private var error: Error?
    
    var body: some View {
        InfoScreen(
            infoText: "Default",
            username: "User",
            email: "Email",
            creationDate: "Creation Date",
            portalName: "Portal Name",
            userThumbnail: UIImage(systemName: "person.crop.circle.fill")!,
            isLoading: false
        )
        .onAppear {
            model.setAuthenticator()
        }
        .onDisappear {
            Task {
                await model.clearAuthenticator()
            }
        }
        .authenticator(model.authenticator)
        .task {
            // Loads the portal user when the view appears.
            do {
                try await model.loadPortalUser()
            } catch {
                self.error = error
            }
        }
    }
    
    /// Sets up new ArcGIS and Network credential stores that will be persisted in the keychain.
    private func setupPersistentCredentialStorage() async throws {
        try await ArcGISEnvironment.authenticationManager.setupPersistentCredentialStorage(
            access: .whenUnlockedThisDeviceOnly,
            synchronizesWithiCloud: false
        )
    }
}

private extension ShowPortalUserInfoView {
    @MainActor
    @Observable
    class Model {
        /// The authenticator to handle authentication challenges.
        var authenticator: Authenticator
        /// The API key to use temporarily while using OAuth.
        var apiKey: APIKey?
        /// A list of portal items when the portal is logged in.
        var portalItems: [PortalItem] = []
        /// The portal user when the portal is logged in.
        var portalUser: PortalUser?
        
        init() {
            self.authenticator = Authenticator(
                oAuthUserConfigurations: [.arcgisDotCom]
            )
        }
        
        func setAuthenticator() {
            // Sets authenticator as ArcGIS and Network challenge handlers to
            // handle authentication challenges.
            ArcGISEnvironment.authenticationManager.handleChallenges(using: authenticator)
            // Temporarily unsets the API key for this sample to use OAuth.
            apiKey = ArcGISEnvironment.apiKey
            ArcGISEnvironment.apiKey = nil
        }
        
        func clearAuthenticator() async {
            // Resets challenge handlers.
            ArcGISEnvironment.authenticationManager.handleChallenges(using: nil)
            // Sets the API key back to the original value.
            ArcGISEnvironment.apiKey = apiKey
            Task {
                await signOut()
            }
        }
        
        /// Signs out from the portal by revoking OAuth tokens and clearing credential stores.
        private func signOut() async {
            await ArcGISEnvironment.authenticationManager.revokeOAuthTokens()
            await ArcGISEnvironment.authenticationManager.clearCredentialStores()
        }
        
        func loadPortalUser() async throws {
            let portal = Portal.arcGISOnline(connection: .authenticated)
            try await portal.load()
            portalUser = portal.user
        }
    }
    
    struct InfoScreen: View {
        var infoText: String
        var username: String
        var email: String
        var creationDate: String
        var portalName: String
        var userThumbnail: UIImage
        var isLoading: Bool
        
        var body: some View {
            ScrollView {
                VStack(spacing: 16) {
                    if isLoading {
                        ProgressView().padding()
                    } else {
                        Text(infoText)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                    Divider()
                    Image(uiImage: userThumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 150, height: 150)
                        .clipShape(Circle())
                        .clipped()
                    Divider()
                    InfoRow(label: "Username:", value: username)
                    Divider()
                    InfoRow(label: "E-mail:", value: email)
                    Divider()
                    InfoRow(label: "Member Since:", value: creationDate)
                    Divider()
                    InfoRow(label: "Portal Name:", value: portalName)
                    Divider()
                }
                .padding()
            }
        }
    }
    
    struct InfoRow: View {
        var label: String
        var value: String
        
        var body: some View {
            HStack {
                Text(label).fontWeight(.bold)
                Text(value)
                Spacer()
            }
            .padding(.horizontal)
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

#Preview {
    ShowPortalUserInfoView()
}
