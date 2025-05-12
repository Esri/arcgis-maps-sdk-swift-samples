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

struct AuthenticateWithIntegratedWindowsAuthenticationView: View {
    /// The authenticator to handle authentication challenges.
    @StateObject private var authenticator = Authenticator(promptForUntrustedHosts: true)
    
    @State private var map: Map?
    
    @State private var isPortalContentPresented = false
    
    var body: some View {
        VStack {
            if let map {
                MapView(map: map)
            }
        }
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button("Portal Content") {
                    isPortalContentPresented = true
                }
                .popover(isPresented: $isPortalContentPresented) {
                    PortalContentView(selection: $map)
                        .presentationDetents([.medium])
                        .frame(idealWidth: 320, idealHeight: 380)
                }
            }
        }
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
    private func signOut() {
        Task {
            await ArcGISEnvironment.authenticationManager.revokeOAuthTokens()
            await ArcGISEnvironment.authenticationManager.clearCredentialStores()
        }
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

#Preview {
    AuthenticateWithIntegratedWindowsAuthenticationView()
}

extension AuthenticateWithIntegratedWindowsAuthenticationView {
    struct PortalContentView: View {
        @State private var portalURLString = ""
        @State private var portalContent: Result<PortalQueryResultSet<PortalItem>, Error>?
        @State private var isConnecting = false
        @Binding var selection: Map?
        
        var portalURL: URL? { URL(string: portalURLString) }
        
        var body: some View {
            Form {
                switch portalContent {
                case .success(let success):
                    ForEach(success.results, id: \.id?.rawValue) { item in
                        Text(item.title)
                            .onTapGesture {
                                selection = Map(item: item)
                            }
                    }
                case .failure:
                    urlEntryView
                    ContentUnavailableView(
                        "Error",
                        systemImage: "exclamationmark.triangle",
                        description: Text("Error searching specified portal.")
                    )
                case nil:
                    urlEntryView
                }
            }
            .animation(.default, value: isConnecting)
        }
        
        @ViewBuilder private var urlEntryView: some View {
            Section {
                HStack {
                    TextField("Portal", text: $portalURLString)
                        .onSubmit { Task { await connect() } }
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                    Button {
                        Task { await connect() }
                    } label: {
                        if isConnecting {
                            ProgressView()
                        } else {
                            Text("Connect")
                        }
                    }
                    .disabled(portalURL == nil)
                    .disabled(isConnecting)
                }
            }
        }
        
        private func connect() async {
            precondition(portalURL != nil)
            
            isConnecting = true
            defer { isConnecting = false }
            
            do {
                let portal = Portal(url: portalURL!)
                try await portal.load()
                let results = try await portal.findItems(queryParameters: .items(ofKinds: [.webMap]))
                portalContent = .success(results)
            } catch {
                portalContent = .failure(error)
            }
        }
    }
}
