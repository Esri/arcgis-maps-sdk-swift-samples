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
    
    /// The action to run when the sample's teardown has completed.
    ///
    /// This is needed to prevent the authentication in this sample from interfering with other samples.
    @Environment(\.onTearDownCompleted) private var onTearDownCompleted
    
    var body: some View {
        Form {
            switch model.portalContent {
            case .success(let success):
                ForEach(success.results, id: \.id?.rawValue) { item in
                    Button(item.title) {
                        model.selectedItem = .init(portalItem: item)
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
        .onDisappear {
            Task {
                // Reset the challenge handlers and clear credentials
                // when the view disappears so that user is prompted to enter
                // credentials every time the sample is run, and to clean
                // the environment for other samples.
                await model.teardownAuthenticator()
                onTearDownCompleted()
            }
        }
        .sheet(item: $model.selectedItem) { selectedItem in
            NavigationStack {
                MapView(map: Map(item: selectedItem.portalItem))
                    .navigationTitle(selectedItem.portalItem.title)
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
            .highPriorityGesture(DragGesture())
            .pagePresentation()
        }
        .animation(.default, value: model.isConnecting)
        .authenticator(model.authenticator)
    }
    
    @ViewBuilder private var urlEntryView: some View {
        Section {
            HStack {
                TextField("IWA Secured Portal URL", text: $model.portalURLString)
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

/// A value that represents an item selected by the user.
private struct SelectedItem: Identifiable {
    /// The portal item that was selected.
    let portalItem: PortalItem
    
    var id: ObjectIdentifier {
        ObjectIdentifier(portalItem)
    }
}

extension AuthenticateWithIntegratedWindowsAuthenticationView {
    @MainActor
    class Model: ObservableObject {
        /// The authenticator to handle authentication challenges.
        let authenticator = Authenticator()
        
        /// The URL string entered by the user.
        @Published var portalURLString = ""
        
        /// The fetched portal content.
        @Published var portalContent: Result<PortalQueryResultSet<PortalItem>, Error>?
        
        /// A Boolean value indicating if a portal connection is in progress.
        @Published var isConnecting = false
        
        /// The selected item.
        @Published fileprivate var selectedItem: SelectedItem?
        
        /// The URL of the portal.
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
            } catch {
                portalContent = .failure(error)
            }
        }
        
        /// Sets up the authenticator to handle challenges.
        private func setupAuthenticator() {
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
}

#Preview {
    AuthenticateWithIntegratedWindowsAuthenticationView()
}
