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

struct AddItemsToPortalView: View {
    /// The authenticator to handle authentication challenges.
    @StateObject private var authenticator = Authenticator(
        oAuthUserConfigurations: [.arcgisDotCom]
    )
    
    /// The API key to temporarily while using OAuth.
    @State private var apiKey: APIKey?
    
    /// A list of portal items when the portal is logged in.
    @State private var portalItems: [PortalItem] = []
    
    /// The portal item to delete when the delete alert is presented.
    @State private var portalItemToDelete: PortalItem?
    
    /// The portal user when the portal is logged in.
    @State private var portalUser: PortalUser?
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    /// A Boolean value indicating whether the delete alert is presented.
    @State private var deleteAlertIsPresented = false
    
    var body: some View {
        Group {
            if portalItems.isEmpty {
                ContentUnavailableView {
                    Label("No Items", systemImage: "exclamationmark.triangle")
                } description: {
                    Text("Portal items will be shown here once you log in and have items in your portal.")
                }
            } else {
                portalItemList
            }
        }
        .authenticator(authenticator)
        .errorAlert(presentingError: $error)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add Portal Item", systemImage: "plus") {
                    Task {
                        do {
                            try await addPortalItem()
                        } catch {
                            self.error = error
                        }
                    }
                }
                .disabled(portalUser == nil)
            }
        }
        .task {
            // Loads the portal user when the view appears.
            do {
                let portal = Portal.arcGISOnline(connection: .authenticated)
                try await portal.load()
                portalUser = portal.user
                try await fetchPortalItems()
            } catch {
                self.error = error
            }
        }
        .onAppear {
            // Setting the challenge handlers here in `onAppear` so user is
            // prompted to enter credentials every time trying the sample.
            // In real world applications, set challenge handlers at the start
            // of the application.
            
            // Sets authenticator as ArcGIS and Network challenge handlers to
            // handle authentication challenges.
            ArcGISEnvironment.authenticationManager.handleChallenges(using: authenticator)
            
            // In real world applications, uncomment this code to persist
            // credentials in the keychain and remove `signOut()` from `onDisappear`.
            // Task { try await setupPersistentCredentialStorage() }
            
            // Temporarily unsets the API key for this sample to use OAuth.
            apiKey = ArcGISEnvironment.apiKey
            ArcGISEnvironment.apiKey = nil
        }
        .onDisappear {
            // Resetting the challenge handlers and clearing credentials here in
            // `onDisappear` so user is prompted to enter credentials every time
            // trying the sample. In real world applications, do these from
            // sign out functionality of the application.
            
            // Resets challenge handlers.
            ArcGISEnvironment.authenticationManager.handleChallenges(using: nil)
            
            // Sets the API key back to the original value.
            ArcGISEnvironment.apiKey = apiKey
            Task { await signOut() }
        }
    }
    
    /// A list of portal items in the user's portal.
    @ViewBuilder private var portalItemList: some View {
        List(portalItems, id: \.id) { portalItem in
            PortalItemView(item: portalItem)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button {
                        portalItemToDelete = portalItem
                        deleteAlertIsPresented = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
        }
        .refreshable {
            try? await fetchPortalItems()
        }
        .alert("Delete Item \(portalItemToDelete?.title ?? "")?", isPresented: $deleteAlertIsPresented) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    do {
                        try await deletePortalItem(portalItemToDelete!)
                    } catch {
                        self.error = error
                    }
                }
            }
        } message: {
            Text("Deleting this item will remove it from your portal.")
        }
    }
    
    /// Adds a new portal item to the portal.
    private func addPortalItem() async throws {
        let imageItem = PortalItem(
            portal: .arcGISOnline(connection: .authenticated),
            kind: .image
        )
        imageItem.title = "Blue Marker"
        let imageData = UIImage.blueMarker.pngData()!
        let parameters = PortalItemContentParameters.data(imageData, filename: "BlueMarker")
        try await portalUser!.add(imageItem, with: parameters)
        
        // Refreshes the portal items list after adding the item.
        try await fetchPortalItems()
    }
    
    /// Deletes the specified portal item.
    /// - Parameter portalItem: The portal item to delete.
    private func deletePortalItem(_ portalItem: PortalItem) async throws {
        try await portalUser!.delete(portalItem)
        
        // Refreshes the portal items list after deletion.
        try await fetchPortalItems()
    }
    
    /// Fetches the portal items from a user.
    private func fetchPortalItems() async throws {
        if let portalUser {
            portalItems = try await portalUser.content.items.sorted {
                ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast)
            }
        }
    }
    
    /// Signs out from the portal by revoking OAuth tokens and clearing credential stores.
    private func signOut() async {
        await ArcGISEnvironment.authenticationManager.revokeOAuthTokens()
        await ArcGISEnvironment.authenticationManager.clearCredentialStores()
    }
    
    /// Sets up new ArcGIS and Network credential stores that will be persisted in the keychain.
    private func setupPersistentCredentialStorage() async throws {
        try await ArcGISEnvironment.authenticationManager.setupPersistentCredentialStorage(
            access: .whenUnlockedThisDeviceOnly,
            synchronizesWithiCloud: false
        )
    }
}

/// A view that displays information about a portal item for viewing in a list.
struct PortalItemView: View {
    /// The portal item to display information about.
    let item: PortalItem
    
    /// The size of the thumbnail.
    private let thumbnailSize = CGFloat(64)
    
    /// The thumbnail image of the map area.
    @State private var thumbnail: UIImage?
    
    var body: some View {
        HStack {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: thumbnailSize, height: thumbnailSize)
                    .clipShape(.rect(cornerRadius: 10))
            } else {
                Image(systemName: "map")
                    .imageScale(.large)
                    .foregroundStyle(.secondary)
                    .frame(width: thumbnailSize, height: thumbnailSize)
                    .background(Color(uiColor: UIColor.systemGroupedBackground))
                    .clipShape(.rect(cornerRadius: 10))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.headline)
                    .lineLimit(1)
                Text("Owner: \(item.owner), Views: \(item.viewCount)")
                    .font(.footnote)
                Text(item.snippet)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .task {
            try? await item.thumbnail?.load()
            thumbnail = item.thumbnail?.image
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
    AddItemsToPortalView()
}
