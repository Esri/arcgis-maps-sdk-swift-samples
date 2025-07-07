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
    @StateObject private var model = PortalUserInfoModel()
    
    var body: some View {
        VStack {
            PortalDetailsView(
                url: $model.portalURLString,
                onSetUrl: { model.portalURLString = $0 },
                onSignOut: { Task { await model.signOut() } },
                onLoadPortal: { Task { await model.connectToPortal() } }
            )
            
            InfoScreen(
                infoText: model.infoText,
                username: model.user?.username ?? "N/A",
                email: model.user?.email ?? "N/A",
                creationDate: model.user?.creationDate?.formatted() ?? "Unknown",
                portalName: model.portalName,
                userThumbnail: model.user?.thumbnail?.image ?? UIImage(systemName: "person.crop.circle.fill")!,
                isLoading: model.isLoading
            )
        }
    }
    
    struct PortalDetailsView: View {
        @Binding var url: String
        var onSetUrl: (String) -> Void
        var onSignOut: () -> Void
        var onLoadPortal: () -> Void
        
        @FocusState private var isTextFieldFocused: Bool
        
        var body: some View {
            VStack(alignment: .center, spacing: 16) {
                TextField("Portal URL", text: $url, onCommit: {
                    onLoadPortal()
                    isTextFieldFocused = false
                })
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .submitLabel(.go)
                .focused($isTextFieldFocused)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                
                HStack {
                    Button("Sign out", action: {
                        onSignOut()
                        isTextFieldFocused = false
                    })
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    
                    Button("Load portal", action: {
                        onLoadPortal()
                        isTextFieldFocused = false
                    })
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
                .padding(.horizontal)
            }
            .padding()
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

extension ShowPortalUserInfoView {
    @MainActor
    class PortalUserInfoModel: ObservableObject {
        let authenticator = Authenticator()
        
        @Published var portalURLString: String = ""
        @Published var infoText: String = "Enter a portal URL to begin."
        @Published var isLoading: Bool = false
        @Published var user: PortalUser?
        @Published var portalName: String = ""
        @Published var error: Error?
        
        private var portal: Portal?
        
        var portalURL: URL? {
            URL(string: portalURLString)
        }
        
        init() {
            setupAuthenticator()
        }
        
        func connectToPortal() async {
            guard let portalURL else {
                infoText = "Invalid portal URL."
                return
            }
            
            isLoading = true
            defer { isLoading = false }
            
            do {
                let portal = Portal(url: portalURL)
                try await portal.load()
                self.portal = portal
                self.user = portal.user
                self.portalName = portal.info?.portalName ?? "Unknown"
                self.infoText = "Portal loaded successfully."
                self.error = nil
            } catch {
                self.portal = nil
                self.user = nil
                self.portalName = ""
                self.infoText = "Failed to load portal: \(error.localizedDescription)"
                self.error = error
            }
        }
        
        func signOut() async {
            await ArcGISEnvironment.authenticationManager.revokeOAuthTokens()
            await ArcGISEnvironment.authenticationManager.clearCredentialStores()
            ArcGISEnvironment.authenticationManager.handleChallenges(using: nil)
            
            user = nil
            portalName = ""
            infoText = "Signed out."
        }
        
        private func setupAuthenticator() {
            ArcGISEnvironment.authenticationManager.handleChallenges(using: authenticator)
        }
    }
}

#Preview {
    ShowPortalUserInfoView()
}
