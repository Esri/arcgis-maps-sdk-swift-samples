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
    /// The model that backs this view.
    @StateObject private var model = Model()
    
    var body: some View {
        Form {
            switch model.portalContent {
            case .success(let success):
                ForEach(success.results, id: \.id?.rawValue) { item in
                    Button(item.title) {
                        model.selectedItem = .init(item: item)
                    }
                    .buttonStyle(.plain)
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
        .sheet(item: $model.selectedItem) { selectedItem in
            NavigationStack {
                MapView(map: selectedItem.map)
                    .navigationTitle(selectedItem.item.title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                model.selectedItem = nil
                            }
                        }
                    }
            }
            .interactiveDismissDisabled()
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

struct SelectedItem: Identifiable {
    let item: PortalItem
    
    var id: ObjectIdentifier {
        ObjectIdentifier(item)
    }
    
    var map: Map {
        Map(item: item)
    }
}

extension AuthenticateWithIntegratedWindowsAuthenticationView {
    @MainActor
    class Model: ObservableObject {
        /// The authenticator to handle authentication challenges.
        let authenticator = Authenticator(promptForUntrustedHosts: true)
        
        /// The URL string entered by the user.
        @Published var portalURLString = ""
        
        /// The fetched portal content.
        @Published var portalContent: Result<PortalQueryResultSet<PortalItem>, Error>?
        
        /// A Boolean value indicating if a portal connection is in progress.
        @Published var isConnecting = false
        
        @Published var isContentListShowing = false
        
        @Published var selectedItem: SelectedItem?
        
        /// The URL to the portal.
        var portalURL: URL? { URL(string: portalURLString) }
        
        init() {
            setupAuthenticator()
        }
        
        /// Connects to the portal and finds a batch of webmaps.
        func connectToPortal() async {
            precondition(portalURL != nil)
            
            isConnecting = true
            defer { isConnecting = false }
            
            do {
                let portal = Portal(url: portalURL!)
                try await portal.load()
                let results = try await portal.findItems(queryParameters: .items(ofKinds: [.webMap]))
                portalContent = .success(results)
                isContentListShowing = true
            } catch {
                portalContent = .failure(error)
            }
        }
        
        deinit {
            teardownAuthenticator()
        }
        
        /// Sets up the authenticator to handle challenges.
        private func setupAuthenticator() {
            // Setting the challenge handlers here when the model is created so user is prompted to enter
            // credentials every time trying the sample. In real world applications, set challenge
            // handlers at the start of the application.
            
            // Sets authenticator as ArcGIS and Network challenge handlers to handle authentication
            // challenges.
            ArcGISEnvironment.authenticationManager.handleChallenges(using: authenticator)
            
            // In real world applications, uncomment this code to persist credentials in the
            // keychain and remove `signOut()` from `deinit`.
            // setupPersistentCredentialStorage()
        }
        
        /// Stops the authenticator from handling the challenges.
        nonisolated private func teardownAuthenticator() {
            // Resetting the challenge handlers and clearing credentials here in deinit
            // so user is prompted to enter credentials every time trying the sample.
            
            // Resets challenge handlers.
            ArcGISEnvironment.authenticationManager.handleChallenges(using: nil)
            
            // In your application, this sign out code may need to run at a different
            // point in time based on the workflow desired. For example, it might make
            // sense to sign out when the user taps a button.
            signOut()
        }
        
        /// Signs out from the portal by revoking OAuth tokens and clearing credential stores.
        nonisolated private func signOut() {
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
}

#Preview {
    AuthenticateWithIntegratedWindowsAuthenticationView()
}
