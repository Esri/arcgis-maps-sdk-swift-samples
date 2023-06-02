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
    
    /// An image that represents an attachment symbol.
    @State var attachmentImage: Image?
    
    /// An image that represents a connectivity symbol.
    @State var connectivityImage: Image?
    
    var body: some View {
        // Creates a map view to display the map.
        MapView(
            map: model.map,
            viewpoint: .initialViewpoint,
            graphicsOverlays: [model.associationsOverlay]
        )
        .onViewpointChanged(kind: .centerAndScale) {
            model.scale = $0.targetScale
        }
        .onViewpointChanged(kind: .boundingGeometry) {
            model.viewpoint = $0
            Task { try await model.addAssociationGraphics() }
        }
        .onDisappear {
            ArcGISEnvironment.authenticationManager.arcGISCredentialStore.removeAll()
        }
        .task {
            await model.setup()
            attachmentImage = model.attachmentImage
            connectivityImage = model.connectivityImage
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                legend
            }
        }
    }
}

private extension ShowUtilityAssociationsView {
    /// The legend at the bottom of the screen.
    var legend: some View {
        HStack {
            attachmentImage
            Text("Attachment")
            Spacer()
            connectivityImage
            Text("Connectivity")
        }
    }
}

private extension ShowUtilityAssociationsView {
    /// The model used to store the geo model and other expensive objects
    /// used in this view.
    class Model: ObservableObject {
        // MARK: Properties
        
        /// The map with the utility network.
        var map = makeMap()
        
        /// A container for associations results.
        var associationsOverlay = GraphicsOverlay()
        
        /// The current viewpoint of the map.
        var viewpoint: Viewpoint?
        
        /// The scale of the viewpoint.
        var scale = 0.0
        
        /// An image that represents an attachment symbol.
        var attachmentImage: Image?
        
        /// An image that represents a connectivity symbol.
        var connectivityImage: Image?
        
        /// A Boolean value indicating if the sample is authenticated.
        private var isAuthenticated = false
        
        /// The max scale for the viewpoint.
        private let maxScale = 2000.0
        
        /// The utility network for this sample.
        private var network: UtilityNetwork? {
            map.utilityNetworks.first
        }
        
        // MARK: Methods
        
        /// Makes a map from a utility network.
        private static func makeMap() -> Map {
            let map = Map(basemapStyle: .arcGISTopographic)
            map.addUtilityNetwork(UtilityNetwork(url: .utilityNetwork))
            return map
        }
        
        /// Performs important tasks including adding credentials, loading and adding operational layers.
        func setup() async {
            do {
                try await createSwatches()
                try await ArcGISEnvironment.authenticationManager.arcGISCredentialStore.add(.publicSample)
                isAuthenticated = true
                try await network?.load()
                addLayers()
                createRenderer()
                try await addAssociationGraphics()
            } catch {
                return
            }
        }
        
        private func addLayers() {
            guard let network else { return }
            // Get all the edges and junctions in the network.
            if let networkSources = network.definition?.networkSources {
                let sourcesByType = Dictionary(grouping: networkSources) { $0.kind }
                
                // Add all edges that are not subnet lines to the map.
                let edgeLayers = sourcesByType[.edge]!
                    .filter { $0.usageKind != .subnetLine }
                    .map { FeatureLayer(featureTable: $0.featureTable) }
                
                map.addOperationalLayers(edgeLayers)
                
                // Add all the junctions to the map.
                let junctionLayers = sourcesByType[.junction]!.map { FeatureLayer(featureTable: $0.featureTable) }
                map.addOperationalLayers(junctionLayers)
            }
        }
        
        private func createRenderer() {
            // Create a renderer for the associations.
            let attachmentValue = UniqueValue(description: "Attachment", label: "", symbol: LineSymbol.attachment, values: [UtilityAssociation.Kind.attachment])
            
            let connectivityValue = UniqueValue(description: "Connectivity", label: "", symbol: LineSymbol.connectivity, values: [UtilityAssociation.Kind.connectivity])
            
            associationsOverlay.renderer = UniqueValueRenderer(
                fieldNames: ["AssociationType"],
                uniqueValues: [attachmentValue, connectivityValue],
                defaultLabel: ""
            )
        }
        
        func addAssociationGraphics() async throws {
            // Check if the current viewpoint is outside of the max scale.
            guard isAuthenticated, scale <= maxScale else { return }
            if let viewpoint {
                let extent = viewpoint.targetGeometry.extent
                // Get all of the associations in extent of the viewpoint.
                if let network {
                    let associations = try await network.associations(forExtent: extent)
                    associations.forEach {
                        // If it the current association does not exist, add it to the graphics overlay.
                        let associationGID = $0.globalID
                        guard !associationsOverlay.graphics.contains(where: {
                            $0.attributes["GlobalId"] as? UUID == associationGID
                        }) else { return }
                        
                        let symbol: Symbol
                        switch $0.kind {
                        case .attachment:
                            symbol = LineSymbol.attachment
                        case .connectivity:
                            symbol = LineSymbol.connectivity
                        default:
                            return
                        }
                        associationsOverlay.addGraphic(
                            Graphic(
                                geometry: $0.geometry,
                                attributes: [
                                    "GlobalId": associationGID,
                                    "AssociationType": $0.kind
                                ],
                                symbol: symbol
                            )
                        )
                    }
                }
            }
        }
        
        // Create swatches for the legend.
        private func createSwatches() async throws {
            let attachmentUIImage = try await LineSymbol.attachment.makeSwatch(scale: 1.0)
            attachmentImage = Image(uiImage: attachmentUIImage)
            
            let connectivityUIImage = try await LineSymbol.connectivity.makeSwatch(scale: 1.0)
            connectivityImage = Image(uiImage: connectivityUIImage)
        }
    }
}

private extension ArcGISCredential {
    /// The public credentials for the data in this sample.
    /// - Note: Never hardcode login information in a production application. This is done solely
    /// for the sake of the sample.
    static var publicSample: ArcGISCredential {
        get async throws {
            try await TokenCredential.credential(
                for: .utilityNetwork,
                username: "viewer01",
                password: "I68VGU^nMurF"
            )
        }
    }
}

private extension LineSymbol {
    /// A green dot.
    static var attachment: LineSymbol {
        SimpleLineSymbol(style: .dot, color: .green, width: 5)
    }
    
    /// A red dot.
    static var connectivity: LineSymbol {
        SimpleLineSymbol(style: .dot, color: .red, width: 5)
    }
}

private extension URL {
    /// The utility network for this sample.
    static var utilityNetwork: URL {
        URL(string: "https://sampleserver7.arcgisonline.com/server/rest/services/UtilityNetwork/NapervilleElectric/FeatureServer")!
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
