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
import Combine
import UIKit

extension DisplayContentOfUtilityNetworkContainerView {
    /// The model used to manage the state of the trace view.
    class Model: ObservableObject {
        // MARK: Properties
        
        /// The status message shown to the user.
        @Published var statusMessage = ""
        
        /// The Naperville Electric Containers web map.
        let map = Map(item: PortalItem.napervilleElectricalNetwork)
        
        /// The graphics overlay to display utility network graphics.
        let graphicsOverlay = GraphicsOverlay()
        
        /// A line symbol to show the bounding extent.
        private let boundingBoxSymbol = SimpleLineSymbol(style: .dash, color: .yellow, width: 3)
        
        /// A line symbol to show the attachment association.
        private let attachmentSymbol = SimpleLineSymbol(style: .dot, color: .green, width: 3)
        
        /// A line symbol to show the connectivity association.
        private let connectivitySymbol = SimpleLineSymbol(style: .dot, color: .red, width: 3)
        
        /// The feature layers that allow us to fetch the legend symbols of
        /// different elements in the network.
        private let featureLayers: [FeatureLayer] = {
           let layerIDs = [1, 5]
            return layerIDs.map { layerID in
                let url: URL = .featureService.appendingPathComponent("\(layerID)")
                let table = ServiceFeatureTable(url: url)
                return FeatureLayer(featureTable: table)
            }
        }()
        
        /// The utility network for this sample.
        private var network: UtilityNetwork!
        
        /// The legends for elements in the utility network.
        private(set) var legendItems: [LegendItem] = []
        
        // MARK: Methods
        
        /// Performs tasks including loading the network and adding legends.
        func setup() async {
            // Loads the utility network.
            do {
                // Updates the URL session challenge handler to use the
                // specified credentials and tokens for any challenges.
                ArcGISEnvironment.authenticationManager.arcGISAuthenticationChallengeHandler = ChallengeHandler()
                
                // Creates and loads the utility network.
                network = UtilityNetwork(url: .featureService, map: map)
                try await network.load()
                await setStatusMessage("Tap on a container to see its content.")
            } catch {
                await setStatusMessage("An error occurred while loading the network.")
            }
        }
        
        deinit {
            // Resets the URL session challenge handler to use default handling.
            ArcGISEnvironment.authenticationManager.arcGISAuthenticationChallengeHandler = nil
        }
        
        // MARK: Legend
        
        /// Creates legend items with a name and an image.
        /// - Parameter displayScale: The display scale for the swatch images.
        /// - Returns: An array of legends.
        func updateLegendInfoItems(displayScale: CGFloat) async {
            await setStatusMessage("Getting Legend Info…")
            // The legend info array that contains all the info from each feature layer.
            let legendInfos: [LegendInfo] = await withTaskGroup(of: [LegendInfo].self) { group in
                for layer in featureLayers {
                    group.addTask { (try? await layer.legendInfos) ?? [] }
                }
                var infos: [LegendInfo] = []
                for await infosFromLayer in group {
                    infos.append(contentsOf: infosFromLayer)
                }
                return infos
            }
            
            // The symbols used to display the container view boundary
            // and associations.
            let additionalSymbolItems = [
                ("Bounding Box", boundingBoxSymbol),
                ("Attachment", attachmentSymbol),
                ("Connectivity", connectivitySymbol)
            ]
            
            // The symbols from the legend info.
            let featureLayerSymbolItems: [(String, Symbol)] = legendInfos.compactMap { legendInfo in
                if !legendInfo.name.isEmpty,
                   let symbol = legendInfo.symbol {
                    return (legendInfo.name, symbol)
                } else {
                    return nil
                }
            }
            
            // Creates swatches from each symbol.
            await setStatusMessage("Getting Legend Symbol Swatches…")
            let legendItems: [LegendItem] = await withTaskGroup(of: LegendItem?.self) { group in
                var items: [LegendItem] = []
                for (name, symbol) in featureLayerSymbolItems.filter({ $0.0 != "Unknown" }) + additionalSymbolItems {
                    group.addTask {
                        if let swatch = try? await symbol.makeSwatch(scale: displayScale) {
                            return LegendItem(name: name, image: swatch)
                        } else {
                            return nil
                        }
                    }
                }
                for await legendItem in group where legendItem != nil {
                    items.append(legendItem!)
                }
                return items
            }
            // Updates the legend items in the model.
            self.legendItems = legendItems.sorted { $0.name < $1.name }
        }
        
        // MARK: Network Association Graphics
        
        /// Creates graphics for the associations and content in the
        /// container element.
        /// - Parameter feature: The container element's feature.
        func handleIdentifiedFeature(_ feature: ArcGISFeature) async throws {
            let containerElement = network.makeElement(arcGISFeature: feature)!
            let contentElements = try await makeContentElements(containerElement: containerElement)
            let contentGraphics = try await makeGraphicsForContentElements(contentElements, within: containerElement)
            graphicsOverlay.addGraphics(contentGraphics)
            
            if contentGraphics.count == 1 {
                await setStatusMessage("This feature contains no associations.")
            } else {
                await setStatusMessage("Contained associations are shown.")
            }
            
            if let extent = graphicsOverlay.extent {
                let associationsGraphics = try await makeGraphicsForAssociations(within: extent)
                let boundingBoxGraphic = Graphic(geometry: GeometryEngine.buffer(around: extent, distance: 0.05)!, symbol: boundingBoxSymbol)
                graphicsOverlay.addGraphics(associationsGraphics)
                graphicsOverlay.addGraphic(boundingBoxGraphic)
            }
        }
        
        /// Creates content elements within the container element.
        /// - Parameter containerElement: The container element.
        /// - Returns: An array of utility elements in the container.
        private func makeContentElements(containerElement: UtilityElement) async throws -> [UtilityElement] {
            // Gets the containment associations from the element to display its content.
            let containmentAssociations = try await network.associations(for: containerElement, ofKind: .containment)
            // Determines the relationship of each element and add it to the content elements.
            let contentElements: [UtilityElement] = containmentAssociations.map { association in
                if association.fromElement.objectID == containerElement.objectID {
                    return association.toElement
                } else {
                    return association.fromElement
                }
            }
            return contentElements
        }
        
        /// Creates the graphics for the utility elements within a container.
        /// - Parameters:
        ///   - contentElements: The elements within the container.
        ///   - containerElement: The container element.
        /// - Returns: An array of graphics.
        private func makeGraphicsForContentElements(_ contentElements: [UtilityElement], within containerElement: UtilityElement)  async throws -> [Graphic] {
            let contentFeatures = try await network.features(for: contentElements)
            let graphics: [Graphic] = contentFeatures.compactMap { feature in
                guard let featureTable = feature.table as? ServiceFeatureTable,
                      let symbol = featureTable.layerInfo?.drawingInfo?.renderer?.symbol(for: feature) else {
                    return nil
                }
                return Graphic(geometry: feature.geometry, symbol: symbol)
            }
            return graphics
        }
        
        /// Creates the associations graphics for elements in the container.
        /// - Parameter boundingExtent: The boundary for the container.
        /// - Returns: An array of association relationship graphics.
        private func makeGraphicsForAssociations(within boundingExtent: Envelope) async throws -> [Graphic] {
            let containmentAssociations = try await network.associations(forExtent: boundingExtent)
            let graphics: [Graphic] = containmentAssociations.map { association in
                let symbol = association.kind == .attachment ? attachmentSymbol : connectivitySymbol
                return Graphic(geometry: association.geometry, symbol: symbol)
            }
            return graphics
        }
        
        // MARK: Helpers
        
        /// Changes the visibility of the operational layers.
        /// - Parameter isVisible: A Boolean to make the map visible or not.
        func setOperationalLayersVisibility(isVisible: Bool) {
            map.operationalLayers.forEach { $0.isVisible = isVisible }
        }
        
        /// Sets status message.
        /// - Parameter message: A message of the current status.
        @MainActor
        private func setStatusMessage(_ message: String) {
            statusMessage = message
        }
    }
}

private extension PortalItem {
    /// A web map portal item for the Naperville Electric Containers.
    static var napervilleElectricalNetwork: PortalItem {
        PortalItem(
            // Sample server 7 authentication required.
            portal: Portal(url: .samplePortal, connection: .authenticated),
            id: .init("813eda749a9444e4a9d833a4db19e1c8")!
        )
    }
}

private extension URL {
    /// The server containing the data for this sample.
    private static var sampleServer7: URL {
        URL(string: "https://sampleserver7.arcgisonline.com")!
    }
    
    /// The feature service containing the data for this sample.
    static var featureService: URL {
        sampleServer7.appendingPathComponent("server/rest/services/UtilityNetwork/NapervilleElectric/FeatureServer")
    }
    
    /// The portal containing the data for this sample.
    static var samplePortal: URL {
        sampleServer7.appendingPathComponent("portal")
    }
}

/// A struct for displaying legend info in a list row.
struct LegendItem {
    /// The description label of the legend item.
    let name: String
    
    /// The image swatch of the legend item.
    let image: UIImage
}

// MARK: Authentication

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
