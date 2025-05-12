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

extension AuthenticateWithIntegratedWindowsAuthenticationView {
    @MainActor
    class Model: ObservableObject {
        /// The authenticator to handle authentication challenges.
        let authenticator = Authenticator(promptForUntrustedHosts: true)
        @Published var portalURLString = ""
        @Published var portalContent: Result<PortalQueryResultSet<PortalItem>, Error>?
        @Published var isConnecting = false
        
        var portalURL: URL? { URL(string: portalURLString) }
        
        init() {
            // Setting the challenge handlers here when the model is created so user is prompted to enter
            // credentials every time trying the sample. In real world applications, set challenge
            // handlers at the start of the application.
            
            // Sets authenticator as ArcGIS and Network challenge handlers to handle authentication
            // challenges.
            ArcGISEnvironment.authenticationManager.handleChallenges(using: authenticator)
            
            // In real world applications, uncomment this code to persist credentials in the
            // keychain and remove `signOut()` from `onDisappear`.
            // setupPersistentCredentialStorage()
        }
        
        func connectToPortal() async {
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
        
        deinit {
            // Resetting the challenge handlers and clearing credentials here in deinit
            // so user is prompted to enter credentials every time trying the sample. In real
            // world applications, this sign out code may need to run at a different
            // point in time based on the workflow desired.
            
            // Resets challenge handlers.
            ArcGISEnvironment.authenticationManager.handleChallenges(using: nil)
            
            signOut()
        }
        
        /// Signs out from the portal by revoking OAuth tokens and clearing credential stores.
        nonisolated private func signOut() {
            Task.detached {
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
}

struct AuthenticateWithIntegratedWindowsAuthenticationView: View {
    @StateObject private var model = Model()
    
    var body: some View {
        Form {
            switch model.portalContent {
            case .success(let success):
                ForEach(success.results, id: \.id?.rawValue) { item in
                    NavigationLink(item.title) {
                        MapView(map: Map(item: item))
                            .navigationTitle(item.title)
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
                if model.isConnecting {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    urlEntryView
                }
            }
        }
        .animation(.default, value: model.isConnecting)
        .authenticator(model.authenticator)
    }
    
    @ViewBuilder private var urlEntryView: some View {
        Section {
            HStack {
                TextField("Portal", text: $model.portalURLString)
                    .onSubmit { Task { await model.connectToPortal() } }
                    .autocapitalization(.none)
                    .keyboardType(.URL)
                Button("Connect") {
                    Task { await model.connectToPortal() }
                }
                .disabled(model.portalURL == nil)
            }
        }
    }
}

#Preview {
    AuthenticateWithIntegratedWindowsAuthenticationView()
}
