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
   @State private var map = makeMap()
    
    /// A container for associations results.
    @State var associationsOverlay = GraphicsOverlay()
    
    /// The utility network for this sample.
    private var network: UtilityNetwork? {
        map.utilityNetworks.first
    }
    
    var body: some View {
        // Creates a map view to display the map.
        MapView(
            map: map,
            viewpoint: .initialViewpoint,
            graphicsOverlays: [associationsOverlay]
        )
        .onViewpointChanged(kind: .centerAndScale) { newViewpoint in
            addAssociationGraphics()
        }
        .task {
            await setup()
        }
        .onDisappear {
            ArcGISEnvironment.authenticationManager.arcGISCredentialStore.removeAll()
        }
    }
    
    /// Makes a map from a utility network.
    static func makeMap() -> Map {
        let map = Map(basemapStyle: .arcGISTopographic)
        map.addUtilityNetwork(UtilityNetwork(url: .utilityNetwork))
        return map
    }
    
    /// Performs important tasks including adding credentials, loading and adding operational layers.
    func setup() async {
        do {
            try await ArcGISEnvironment.authenticationManager.arcGISCredentialStore.add(.publicSample)
            try await network?.load()
            addLayers()
            createRenderer()
            createSwatches()
            addAssociationGraphics()
        } catch {
            return
        }
    }
    
    func addLayers() {
        guard let network else { return }
        // Get all the edges and junctions in the network.
        if let networkSources = network.definition?.networkSources {
            let sourcesByType = Dictionary(grouping: networkSources) { $0.kind }
            
            // Add all edges that are not subnet lines to the map.
            let edgeLayers = sourcesByType[.edge]!
                .filter { $0.usageKind != .subnetLine}
                .map { FeatureLayer(featureTable: $0.featureTable) }
            
            map.addOperationalLayers(edgeLayers)
            
            // Add all the junctions to the map.
            let junctionLayers = sourcesByType[.junction]!.map { FeatureLayer(featureTable: $0.featureTable) }
            map.addOperationalLayers(junctionLayers)
        }
    }
    
    func createRenderer() {
        // Create a renderer for the associations.
        let attachmentValue = UniqueValue(description: "Attachment", label: "", symbol: LineSymbol.attachment, values: [UtilityAssociation.Kind.attachment])
        
        let connectivityValue = UniqueValue(description: "Connectivity", label: "", symbol: LineSymbol.connectivity, values: [UtilityAssociation.Kind.connectivity])
        
        associationsOverlay.renderer = UniqueValueRenderer(
            fieldNames: ["AssociationType"],
            uniqueValues: [attachmentValue, connectivityValue],
            defaultLabel: ""
        )
    }
    
    func addAssociationGraphics() {
        
    }
    
    // Populate the legend.
    func createSwatches() {
        
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
