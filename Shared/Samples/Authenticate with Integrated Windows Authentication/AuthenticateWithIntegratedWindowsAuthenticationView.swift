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
    @StateObject private var authenticator = Authenticator()
    
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
        
        @Binding var selection: Map?
        
        var body: some View {
            List {
                TextField("Portal", text: $portalURLString)
            }
        }
    }
}
