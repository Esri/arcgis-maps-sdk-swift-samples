// Copyright 2023 Esri
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
import SwiftUI

struct ShowUtilityAssociationsView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// The current viewpoint of the map.
    @State private var viewpoint: Viewpoint = .initialViewpoint
    
    /// The scale of the viewpoint.
    @State private var scale: Double = .zero
    
    /// An image that represents an attachment symbol.
    @State private var attachmentImage: UIImage?
    
    /// An image that represents a connectivity symbol.
    @State private var connectivityImage: UIImage?
    
    /// The display scale of this environment.
    @Environment(\.displayScale) private var displayScale
    
    var body: some View {
        MapView(
            map: model.map,
            viewpoint: viewpoint,
            graphicsOverlays: [model.associationsOverlay]
        )
        .onScaleChanged {
            scale = $0
            Task { try await model.addAssociationGraphics(viewpoint: viewpoint, scale: scale) }
        }
        .onViewpointChanged(kind: .boundingGeometry) {
            viewpoint = $0
            Task { try await model.addAssociationGraphics(viewpoint: viewpoint, scale: scale) }
        }
        .task {
            try? await model.setup()
            try? await model.addAssociationGraphics(viewpoint: viewpoint, scale: scale)
        }
        .overlay(alignment: .topLeading) {
            legend
                .padding()
                .background(.thinMaterial)
                .clipShape(.rect(cornerRadius: 10))
                .shadow(radius: 3)
                .padding()
        }
        .onTeardown {
            model.tearDown()
        }
    }
}

private extension ShowUtilityAssociationsView {
    /// The legend for the utility associations.
    var legend: some View {
        VStack {
            Label {
                Text("Attachment")
            } icon: {
                if let attachmentImage {
                    Image(uiImage: attachmentImage)
                } else {
                    Color.clear
                }
            }
            .task(id: displayScale) {
                attachmentImage = try? await Symbol.attachment
                    .makeSwatch(scale: displayScale)
            }
            Label {
                Text("Connectivity")
            } icon: {
                if let connectivityImage {
                    Image(uiImage: connectivityImage)
                } else {
                    Color.clear
                }
            }
            .task(id: displayScale) {
                connectivityImage = try? await Symbol.connectivity
                    .makeSwatch(scale: displayScale)
            }
        }
        .labelStyle(.titleAndIcon)
    }
}

private extension ShowUtilityAssociationsView {
    /// The model used to store the geo model and other expensive objects
    /// used in this view.
    @MainActor
    class Model: ObservableObject {
        // MARK: Properties
        
        /// The map with the utility network.
        let map = Map(item: .napervilleElectricNetwork())
        
        /// The utility network for this sample.
        private var network: UtilityNetwork { map.utilityNetworks.first! }
        
        /// A container for associations results.
        let associationsOverlay = makeAssociationsOverlay()
        
        /// A Boolean value indicating if the sample is authenticated.
        private var isAuthenticated: Bool {
            !ArcGISEnvironment.authenticationManager.arcGISCredentialStore.credentials.isEmpty
        }
        
        /// A Boolean value indicating if graphics are being added to the associations overlay.
        private var isAddingGraphics = false
        
        /// The max scale for the viewpoint.
        private var maxScale: Double { 2_000 }
        
        init() {
            // Updates the URL session challenge handler to use the
            // specified credentials and tokens for any challenges.
            ArcGISEnvironment.authenticationManager.arcGISAuthenticationChallengeHandler = ChallengeHandler()
        }
        
        // MARK: Methods
        
        /// Loads the map and the utility network.
        func setup() async throws {
            try await map.load()
            try await network.load()
        }
        
        /// Cleans up the model's setup.
        func tearDown() {
            // Resets the URL session challenge handler to use default handling
            // and removes all credentials.
            ArcGISEnvironment.authenticationManager.arcGISAuthenticationChallengeHandler = nil
            ArcGISEnvironment.authenticationManager.arcGISCredentialStore.removeAll()
        }
        
        static func makeAssociationsOverlay() -> GraphicsOverlay {
            let attachmentValue = UniqueValue(
                description: "Attachment",
                label: "",
                symbol: .attachment,
                values: [UtilityAssociation.Kind.attachment]
            )
            let connectivityValue = UniqueValue(
                description: "Connectivity",
                label: "",
                symbol: .connectivity,
                values: [UtilityAssociation.Kind.connectivity]
            )
            
            let renderer = UniqueValueRenderer(
                fieldNames: ["AssociationType"],
                uniqueValues: [attachmentValue, connectivityValue],
                defaultLabel: ""
            )
            
            let overlay = GraphicsOverlay()
            overlay.renderer = renderer
            return overlay
        }
        
        func addAssociationGraphics(viewpoint: Viewpoint, scale: Double) async throws {
            // Check if the current viewpoint is outside of the max scale.
            guard isAuthenticated, scale <= maxScale, !isAddingGraphics else { return }
            isAddingGraphics = true
            let extent = viewpoint.targetGeometry.extent
            // Get all of the associations in extent of the viewpoint.
            let associations = try await network.associations(forExtent: extent)
            let existingAssociationIDs = Set(
                associationsOverlay.graphics.compactMap { $0.attributes["GlobalId"] as? UUID }
            )
            let graphics: [Graphic] = associations
                .compactMap { association in
                    let associationID = association.globalID
                    guard !existingAssociationIDs.contains(associationID),
                          let symbol = symbol(for: association.kind) else { return nil }
                    
                    return Graphic(
                        geometry: association.geometry,
                        attributes: [
                            "GlobalId": associationID,
                            "AssociationType": association.kind
                        ],
                        symbol: symbol
                    )
                }
            associationsOverlay.addGraphics(graphics)
            isAddingGraphics = false
        }
        
        func symbol(for associationKind: UtilityAssociation.Kind) -> Symbol? {
            switch associationKind {
            case .attachment:
                return Symbol.attachment
            case .connectivity:
                return Symbol.connectivity
            default:
                return nil
            }
        }
    }
}

private extension Symbol {
    /// A green dot.
    static var attachment: LineSymbol {
        SimpleLineSymbol(style: .dot, color: .green, width: 5)
    }
    
    /// A red dot.
    static var connectivity: LineSymbol {
        SimpleLineSymbol(style: .dot, color: .red, width: 5)
    }
}

private extension Item {
    /// A web map portal item for the Naperville Electric Map.
    static func napervilleElectricNetwork() -> PortalItem {
        PortalItem(
            // Sample server 7 authentication required.
            portal: Portal(
                url: URL(string: "https://sampleserver7.arcgisonline.com/portal")!,
                connection: .authenticated
            ),
            id: .init("be0e4637620a453584118107931f718b")!
        )
    }
}

/// The authentication model used to handle challenges and credentials.
private struct ChallengeHandler: ArcGISAuthenticationChallengeHandler {
    func handleArcGISAuthenticationChallenge(
        _ challenge: ArcGISAuthenticationChallenge
    ) async throws -> ArcGISAuthenticationChallenge.Disposition {
        // NOTE: Never hardcode login information in a production application.
        // This is done solely for the sake of the sample.
        return .continueWithCredential(
            // Credentials for sample server 7 services.
            try await TokenCredential.credential(for: challenge, username: "viewer01", password: "I68VGU^nMurF")
        )
    }
}

private extension Viewpoint {
    /// The initial viewpoint to be displayed when the sample is first opened.
    static var initialViewpoint: Viewpoint {
        .init(
            latitude: 41.8057655,
            longitude: -88.1489692,
            scale: 70.5310735
        )
    }
}

#Preview {
    NavigationStack {
        ShowUtilityAssociationsView()
    }
}
