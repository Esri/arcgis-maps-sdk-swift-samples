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
    
    /// The error that occurred, if any, when trying to save the map to the portal.
    @State private var error: Error?
    
    /// The status of the sample workflow.
    @State private var status: Status = .loadingPortal
    
    /// The API key to use temporarily while using OAuth.
    @State private var apiKey: APIKey?
    
    @State private var folders: [PortalFolder]?
    
    var body: some View {
        VStack {
            if let map {
                MapView(map: map)
            } else {
                switch status {
                case .loadingPortal:
                    ProgressView("Loading portal...")
                case .failedToLoadPortal:
                    ContentUnavailableView(
                        "Error",
                        systemImage: "exclamationmark.triangle",
                        description: Text("Portal could not be loaded.")
                    )
                case .creatingMap, .savingMapToPortal:
                    SaveMapForm(portal: portal, folders: folders ?? [], status: $status)
                case .failedToSaveMap:
                    ContentUnavailableView(
                        "Error",
                        systemImage: "exclamationmark.triangle",
                        description: Text("Failed to save map to portal.")
                    )
                case .mapSavedSuccessfully:
                    ContentUnavailableView {
                        Label("Success", systemImage: "checkmark.circle")
                    } description: {
                        Text("Map saved successfully to the portal.")
                    } actions: {
                        Button("Delete Map From Portal") {
                            Task { await deleteFromPortal() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                case .deletingMap:
                    ProgressView("Deleting map...")
                case .deletedSuccessfully:
                    ContentUnavailableView(
                        "Success",
                        systemImage: "checkmark.circle",
                        description: Text("Map successfully deleted from the portal.")
                    )
                case .failedToDelete:
                    ContentUnavailableView(
                        "Error",
                        systemImage: "exclamationmark.triangle",
                        description: Text("Failed to delete map from portal.")
                    )
                }
            }
        }
        .task {
            do {
                try await portal.load()
                let content = try await portal.user?.content
                if let folders = content?.folders {
                    self.folders = Array(folders.prefix(10))
                }
                status = .creatingMap
            } catch {
                status = .failedToLoadPortal
            }
        }
        .errorAlert(presentingError: $error)
        .authenticator(authenticator)
        .onAppear {
            // Temporarily unsets the API key for this sample to use OAuth.
            apiKey = ArcGISEnvironment.apiKey
            ArcGISEnvironment.apiKey = nil
            
            // Setup the authenticator.
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
            
            // Sets the API key back to the original value.
            ArcGISEnvironment.apiKey = apiKey
        }
    }
    
    private func deleteFromPortal() async {
        guard case .mapSavedSuccessfully(let map) = status else {
            return
        }
        do {
            status = .deletingMap
            try await portal.user?.delete(map.item! as! PortalItem)
            status = .deletedSuccessfully
        } catch {
            status = .failedToDelete
        }
    }
}

private extension CreateAndSaveMapView {
    struct SaveMapForm: View {
        let portal: Portal
        let folders: [PortalFolder]
        
        @Binding var status: Status
        
        @State private var title: String = ""
        @State private var tags: String = ""
        @State private var description: String = ""
        @State private var basemap: BasemapOption = .topo
        @State private var operationalData: OperationalDataOption = .none
        @State private var folder: PortalFolder?
        
        @State private var map = Map(basemapStyle: BasemapOption.topo.style)
        @State private var viewpoint: Viewpoint?
        
        var body: some View {
            MapViewReader { mapViewProxy in
                Form {
                    Section("Create Map") {
                        TextField("Title", text: $title)
                        TextField("Tags", text: $tags)
                            .autocorrectionDisabled()
                        TextField("Description", text: $description)
                        Picker("Folder", selection: $folder) {
                            ForEach(folders, id: \.self) { folder in
                                Text(folder.title)
                                    .tag(folder)
                            }
                            Text("None")
                                .tag(Optional<PortalFolder>.none)
                        }
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
                    Section {
                        MapView(map: map)
                            .onViewpointChanged(kind: .centerAndScale) { viewpoint = $0 }
                            .highPriorityGesture(DragGesture())
                            .frame(height: 300)
                    }
                    Section {
                        Button {
                            Task { await save(mapViewProxy: mapViewProxy) }
                        } label: {
                            if status == .savingMapToPortal {
                                HStack {
                                    Text("Saving")
                                    ProgressView()
                                }
                            } else {
                                Text("Save to Portal")
                            }
                        }
                        .disabled(title.isEmpty)
                        .frame(maxWidth: .infinity)
                    }
                }
                .disabled(status == .savingMapToPortal)
                .onChange(of: basemap) { map.basemap = Basemap(style: basemap.style) }
                .onChange(of: operationalData) {
                    map.removeAllOperationalLayers()
                    if let layer = operationalData.layer {
                        map.addOperationalLayer(layer)
                    }
                }
            }
        }
        
        private func save(mapViewProxy: MapViewProxy) async {
            do {
                status = .savingMapToPortal
                map.initialViewpoint = viewpoint
                try await map
                    .save(
                        to: portal,
                        title: title,
                        forceSaveToSupportedVersion: false,
                        folder: folder,
                        description: description,
                        thumbnail: try? await mapViewProxy.exportImage(),
                        tags: tags.components(separatedBy: ",")
                    )
                status = .mapSavedSuccessfully(map)
            } catch {
                status = .failedToSaveMap
            }
        }
    }
}

private extension CreateAndSaveMapView.SaveMapForm {
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
        
        private var url: URL? {
            switch self {
            case .none:
                nil
            case .timeZones:
                URL(string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/WorldTimeZones/MapServer")!
            case .census:
                URL(string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/Census/MapServer")!
            }
        }
        
        var layer: ArcGISMapImageLayer? {
            url.map(ArcGISMapImageLayer.init(url:))
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
    enum Status: Equatable {
        case loadingPortal
        case failedToLoadPortal
        case creatingMap
        case savingMapToPortal
        case failedToSaveMap
        case mapSavedSuccessfully(Map)
        case deletingMap
        case deletedSuccessfully
        case failedToDelete
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
