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

struct CreateAndSaveMapView: View {
    /// The authenticator to handle authentication challenges.
    @StateObject private var authenticator = Authenticator()
    
    /// The portal to save the map to.
    @State private var portal = Portal(
        url: URL(string: "https://www.arcgis.com")!,
        connection: .authenticated
    )
    
    /// The map that we will save to the portal.
    @State private var map: Map?
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    var body: some View {
        VStack {
            if let map {
                MapView(map: map)
            } else {
                MapOptionsForm()
            }
        }
        .errorAlert(presentingError: $error)
        .authenticator(authenticator)
        .onAppear {
            setupAuthenticator()
        }
        .onDisappear {
            Task {
                // Reset the challenge handlers and clear credentials
                // when the view disappears so that user is prompted to enter
                // credentials every time the sample is run, and to clean
                // the environment for other samples.
                await teardownAuthenticator()
            }
        }
    }
}

private extension CreateAndSaveMapView {
    struct MapOptionsForm: View {
        @State private var title: String = ""
        @State private var tags: String = ""
        @State private var description: String = ""
        // @State private var folder: String = ""
        @State private var basemap: BasemapOption = .topo
        @State private var operationalData: OperationalDataOption = .none
        
        var body: some View {
            Form {
                TextField("Title", text: $title)
                TextField("Tags", text: $tags)
                    .autocorrectionDisabled()
                TextField("Description", text: $description)
                Picker("Basemap", selection: $basemap) {
                    ForEach(BasemapOption.allCases, id: \.self) { value in
                        Text(value.label)
                            .tag(value)
                    }
                }
                Picker("Operational Data", selection: $operationalData) {
                    ForEach(OperationalDataOption.allCases, id: \.self) { value in
                        Text(value.label)
                            .tag(value)
                    }
                }
            }
        }
    }
}

private extension CreateAndSaveMapView.MapOptionsForm {
    enum BasemapOption: CaseIterable {
        case topo
        case streets
        case night
        
        var style: Basemap.Style {
            switch self {
            case .topo:
                .arcGISTopographic
            case .streets:
                .arcGISStreets
            case .night:
                .arcGISNavigationNight
            }
        }
        
        var label: String {
            switch self {
            case .topo:
                "Topographic"
            case .streets:
                "Streets"
            case .night:
                "Night Navigation"
            }
        }
    }
    
    enum OperationalDataOption: CaseIterable {
        case none
        case timeZones
        case census
        
        var url: URL? {
            switch self {
            case .none:
                nil
            case .timeZones:
                URL(string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/WorldTimeZones/MapServer")!
            case .census:
                URL(string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/Census/MapServer")!
            }
        }
        
        var label: String {
            switch self {
            case .none:
                "None"
            case .timeZones:
                "Time Zone"
            case .census:
                "Census"
            }
        }
    }
}

private extension CreateAndSaveMapView {
    /// Sets up the authenticator to handle challenges.
    func setupAuthenticator() {
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

#Preview {
    CreateAndSaveMapView()
}
