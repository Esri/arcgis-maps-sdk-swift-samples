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
    /// The data model that helps determine the view.
    @State private var model = Model()
    /// The error shown in the error alert.
    @State private var error: Error?
    
    var body: some View {
        VStack {
            // Shows field for custom portal urls as well as Sign In / Out and Load Portal functions.
            portalDetails
            // If loading, show that the user profile will display when complete.
            if model.portalUser == nil {
                ContentUnavailableView(
                    "Portal User Information",
                    systemImage: "person.crop.circle.dashed",
                    description: Text("Your portal user information will be displayed here.")
                )
            // Otherwise show the user information that was loaded.
            } else {
                InfoScreen(model: $model)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 0, maxHeight: 700)
        .errorAlert(presentingError: $error)
    }
    
    /// Asynchronously loads the portal user information.
    private func loadUser() async {
        do {
            try await model.loadPortalUser()
        } catch {
            // If an error occurs, mark loading as true (to reset)
            // and store the error to present an alert.
            self.error = error
        }
    }
    
    /// A composed view for handling portal login, logout, and URL input.
    @ViewBuilder private var portalDetails: some View {
        PortalDetailsView(
            url: $model.portalURLString,
            model: $model,
            // Update the model when the portal URL is changed by the user.
            onSetUrl: {
                model.portalURLString = $0
            },
            // Sign out the user and reset state.
            onSignOut: {
                Task {
                    await model.signOut()
                }
            },
            // Load the user's portal data when sign in is triggered.
            onLoadPortal: {
                Task {
                    await loadUser()
                }
            }
        )
        // Set up the authenticator when the view appears.
        .onAppear(perform: model.setAuthenticator)
        // Clean up authenticator and credentials when the view disappears.
        .onDisappear {
            Task {
                await model.clearAuthenticator()
            }
        }
        // Attach the authenticator to the view for handling authentication challenges.
        .authenticator(model.authenticator)
    }
}

private extension ShowPortalUserInfoView {
    @MainActor
    @Observable
    class Model {
        /// The authenticator to handle authentication challenges.
        @ObservationIgnored var authenticator: Authenticator
        /// The API key to use temporarily while using OAuth.
        @ObservationIgnored private var apiKey: APIKey?
        /// The URL string of the portal to connect to.
        /// Defaults to the main ArcGIS Online portal.
        var portalURLString: String = "https://www.arcgis.com"
        /// Stores the information related to user's portal.
        var portalInfo: PortalInfo?
        /// Stores the current user's data such as username, email, etc.
        var portalUser: PortalUser?
        /// Indicates whether the model is currently loading data.
        var isLoading: Bool = false
        
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
        
        /// Removes the authenticator and restores the original state.
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
            portalUser = nil
            portalInfo = nil
            isLoading = false
        }
        
        /// Loads portal user information from the specified URL.
        func loadPortalUser() async throws {
            isLoading = true
            // This ensures loading state is cleared even if an error occurs.
            defer { isLoading = false }
            
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
            portalUser = portal.user
            portalInfo = portal.user?.portal?.info
        }
    }
    
    /// A view that manages the portal URL input, sign-in/sign-out actions, and portal loading.
    struct PortalDetailsView: View {
        /// Binding to the portal URL string.
        @Binding var url: String
        /// Binding to the user info model containing user state and data.
        @Binding var model: ShowPortalUserInfoView.Model
        /// Closure called when the portal URL is set or changed.
        var onSetUrl: (String) -> Void
        /// Closure called when the user signs out.
        var onSignOut: () -> Void
        /// Closure called to load the portal user info.
        var onLoadPortal: () -> Void
        
        /// State to track whether the text field is currently focused.
        @FocusState private var isTextFieldFocused: Bool
        
        var body: some View {
            VStack {
                TextField(
                    "Portal URL",
                    text: $url,
                    onCommit: {
                        // When the user finishes editing, load the portal and dismiss keyboard focus.
                        onLoadPortal()
                        isTextFieldFocused = false
                    }
                )
                // Prevent automatic capitalization.
                .textInputAutocapitalization(.never)
                // Use URL keyboard layout.
                .keyboardType(.URL)
                // Show "Go" button on the keyboard.
                .submitLabel(.go)
                // Bind focus state to `isTextFieldFocused`.
                .focused($isTextFieldFocused)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                
                HStack {
                    // Button to sign in or sign out, depending on the loading state.
                    Button(model.portalUser == nil ? "Sign In" : "Sign Out") {
                        if model.portalUser == nil {
                            onLoadPortal()
                        } else {
                            onSignOut()
                        }
                        // Dismiss the keyboard focus after button press.
                        isTextFieldFocused = false
                    }
                    .disabled(model.isLoading)
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                }
                .padding(.horizontal)
            }
            .padding()
        }
    }
    
    /// A view that displays detailed information about the portal user.
    struct InfoScreen: View {
        /// A binding to the model providing user data and loading state.
        @Binding var model: ShowPortalUserInfoView.Model
        
        var body: some View {
            VStack {
                if model.isLoading {
                    // Show a progress indicator while loading user data.
                    ProgressView()
                        .padding()
                } else {
                    // Display additional user information text when data is loaded.
                    Text(model.portalUser?.description ?? "No user data available.")
                        .multilineTextAlignment(.center)
                        .padding()
                }
                Divider()
                // Show the user's thumbnail image as a circular avatar.
                Image(uiImage: model.portalUser?.thumbnail?.image ?? .defaultUserImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 150, height: 150)
                    .clipShape(Circle())
                if let portalUser = model.portalUser {
                    LabeledContent("Username", value: portalUser.username)
                    Divider()
                    LabeledContent("E-mail", value: portalUser.email)
                    Divider()
                    if let creationDate = portalUser.creationDate {
                        LabeledContent("Member Since", value: creationDate, format: .dateTime.day().month().year())
                        Divider()
                    }
                    if let portalInfo = model.portalInfo {
                        LabeledContent("Portal Name", value: portalInfo.portalName)
                    }
                }
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
    /// Default placeholder image.
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
