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

typealias UserDetails = [(String, String)]

struct ShowPortalUserInfoView: View {
    /// The data model that helps determine the view.
    @State private var model = Model()
    /// The error shown in the error alert.
    @State private var error: Error?
    
    var body: some View {
        VStack(spacing: 16) {
            portalDetails
            Group {
                if model.userData.isLoading {
                    ContentUnavailableView(
                        "Portal User Information",
                        systemImage: "exclamationmark.triangle",
                        description: Text("Your portal user information will be displayed here.")
                    )
                } else {
                    InfoScreen(model: $model)
                }
            }
        }
        .errorAlert(presentingError: $error)
    }
    
    private func loadUser() async {
        do {
            try await model.loadPortalUser()
        } catch {
            model.userData.isLoading = true
            self.error = error
        }
    }
    
    @ViewBuilder var portalDetails: some View {
        PortalDetailsView(
            url: $model.portalURLString,
            model: $model,
            onSetUrl: {
                model.portalURLString = $0
            },
            onSignOut: {
                Task {
                    model.userData.isLoading = true
                    await model.signOut()
                }
            },
            onLoadPortal: {
                Task {
                    await loadUser()
                }
            }
        )
        .onAppear(perform: model.setAuthenticator)
        .onDisappear {
            Task {
                await model.clearAuthenticator()
            }
        }
        .authenticator(model.authenticator)
        .task {
            await loadUser()
        }
    }
}

private extension ShowPortalUserInfoView {
    @MainActor
    @Observable
    class Model {
        /// The authenticator to handle authentication challenges.
        @ObservationIgnored var authenticator: Authenticator
        /// The API key to use temporarily while using OAuth.
        @ObservationIgnored var apiKey: APIKey?
        /// A list of portal items when the portal is logged in.
        var portalItems: [PortalItem] = []
        /// The portal user when the portal is logged in.
        var portalUser: PortalUser? {
            didSet {
                let formatter = DateFormatter()
                formatter.dateStyle = .long
                formatter.timeStyle = .none

                let creationDateString = portalUser?.creationDate.map { formatter.string(from: $0) } ?? ""
                
                userData = UserData(
                    infoText: portalUser?.description ?? "",
                    username: portalUser?.username ?? "",
                    email: portalUser?.email ?? "",
                    creationDate: creationDateString,
                    portalName: portalUser?.portal?.info?.portalName ?? "",
                    userThumbnail: portalUser?.thumbnail?.image ?? .defaultUserImage,
                    isLoading: false
                )
            }
        }
        /// This string contains the URL for the portal to connect to.
        var portalURLString: String = "https://www.arcgis.com"
        var userData: UserData
        
        init() {
            self.authenticator = Authenticator(
                oAuthUserConfigurations: [.arcgisDotCom]
            )
          
            userData = UserData(
                infoText: "Default",
                username: "Username",
                email: "Email",
                creationDate: "Date",
                portalName: "Portal Name",
                userThumbnail: .defaultUserImage,
                isLoading: true
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
        
        /// This function cleans up the authenticator and restores the original state.
        func clearAuthenticator() async {
            // This removes our custom challenge handler.
            ArcGISEnvironment.authenticationManager.handleChallenges(using: nil)
            // This restores the original API key.
            ArcGISEnvironment.apiKey = apiKey
            // This signs out to clean up any remaining session.
            await signOut()
        }
        
        /// Signs out from the portal by revoking OAuth tokens and clearing credential stores.
        func signOut() async {
            await ArcGISEnvironment.authenticationManager.revokeOAuthTokens()
            await ArcGISEnvironment.authenticationManager.clearCredentialStores()
        }
        
        /// This function loads portal user information from the specified URL.
        func loadPortalUser() async throws {
            userData.isLoading = true
            // This ensures loading state is cleared even if an error occurs.
            defer { userData.isLoading = false }
            
            // This determines which portal to connect to.
            let portal: Portal
            if portalURLString != "https://www.arcgis.com",
               let customURL = URL(string: portalURLString) {
                // This uses custom portal URL with authentication.
                portal = Portal(url: customURL, connection: .authenticated)
            } else {
                // This uses the default ArcGIS Online portal.
                portal = Portal.arcGISOnline(connection: .authenticated)
            }
            
            // This loads portal information and authenticates user.
            try await portal.load()
            try await portal.user?.thumbnail?.load()
            // This stores the authenticated user.
            portalUser = portal.user
        }
    }
    
    struct UserData {
        var infoText: String
        var username: String
        var email: String
        var creationDate: String
        var portalName: String
        var userThumbnail: UIImage
        var isLoading: Bool
    }
    
    struct PortalDetailsView: View {
        @Binding var url: String
        @Binding var model: ShowPortalUserInfoView.Model
        
        var onSetUrl: (String) -> Void
        var onSignOut: () -> Void
        var onLoadPortal: () -> Void
        
        @FocusState private var isTextFieldFocused: Bool
        
        var body: some View {
            VStack(alignment: .center, spacing: 16) {
                TextField(
                    "Portal URL",
                    text: $url,
                    onCommit: {
                        onLoadPortal()
                        isTextFieldFocused = false
                    }
                )
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .submitLabel(.go)
                .focused($isTextFieldFocused)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                
                HStack {
                    Button(model.userData.isLoading ? "Sign In" : "Sign Out") {
                        if model.userData.isLoading {
                            onLoadPortal()
                            isTextFieldFocused = false
                        } else {
                            onSignOut()
                            isTextFieldFocused = false
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    Button("Load portal") {
                        onLoadPortal()
                        isTextFieldFocused = false
                        print("load portal")
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                }
                .padding(.horizontal)
            }
            .padding()
        }
    }
    
    struct InfoScreen: View {
        @Binding var model: ShowPortalUserInfoView.Model
        
        private var userDetails: UserDetails { [
            ("Username:", model.userData.username),
            ("E-mail:", model.userData.email),
            ("Member Since:", model.userData.creationDate),
            ("Portal Name", model.userData.portalName)
        ] }
        
        var body: some View {
            VStack(spacing: 16) {
                if model.userData.isLoading {
                    ProgressView()
                        .padding()
                } else {
                    Text(model.userData.infoText)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                Divider()
                Image(uiImage: model.userData.userThumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 150, height: 150)
                    .clipShape(Circle())
                ForEach(userDetails, id: \.0) { label, value in
                    Divider()
                    LabeledContent(
                        label,
                        value: value
                    )
                }
                Divider()
            }
            .padding()
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

private extension UIImage {
    static let defaultUserImage = UIImage(systemName: "person.circle")!
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
