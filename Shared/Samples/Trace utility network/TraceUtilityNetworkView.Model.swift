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
import UIKit.UIColor

extension TraceUtilityNetworkView {
    /// The model used to manage the state of the trace view.
    @MainActor
    class Model: ObservableObject {
        // MARK: Properties
        
        /// The domain network for this sample.
        private var electricDistribution: UtilityDomainNetwork? {
            network.definition?.domainNetwork(named: "ElectricDistribution")
        }
        
        /// The textual hint shown to the user.
        @Published var hint: String?
        
        /// The last element that was added to either the list of starting points or barriers.
        ///
        /// When an element contains more than one terminal, the user should be presented with the
        /// option to select a terminal. Keeping a reference to the last added element provides ease
        /// of access to save the user's choice.
        @Published var lastAddedElement: UtilityElement?
        
        /// The last locations in the screen and map where a tap occurred.
        ///
        /// Monitoring these values allows for an asynchronous identification task when they change.
        @Published var lastSingleTap: (screenPoint: CGPoint, mapPoint: Point)?
        
        /// The map contains the utility network and operational layers on which trace results will
        /// be selected.
        let map = Map(item: PortalItem.napervilleElectricNetwork())
        
        /// The utility tier for this sample.
        private var mediumVoltageRadial: UtilityTier? {
            electricDistribution?.tier(named: "Medium Voltage Radial")
        }
        
        /// The utility network for this sample.
        private var network: UtilityNetwork {
            map.utilityNetworks.first!
        }
        
        /// The parameters for the pending trace.
        ///
        /// Important trace information like the trace type, starting points, and barriers is
        /// contained within this value.
        @Published var pendingTraceParameters: UtilityTraceParameters?
        
        /// A Boolean value indicating whether the terminal selection menu is open.
        ///
        /// When a utility element has more than one terminal, the user is presented with a menu of the
        /// available terminal names.
        @Published var terminalSelectorIsOpen = false
        
        /// The current tracing related activity.
        @Published var tracingActivity: TracingActivity?
        
        /// The graphics overlay on which starting point and barrier symbols will be drawn.
        let points: GraphicsOverlay = {
            let overlay = GraphicsOverlay()
            let barrierUniqueValue = UniqueValue(
                symbol: SimpleMarkerSymbol.barrier,
                values: [PointType.barrier.rawValue]
            )
            overlay.renderer = UniqueValueRenderer(
                fieldNames: [String(describing: PointType.self)],
                uniqueValues: [barrierUniqueValue],
                defaultSymbol: SimpleMarkerSymbol.startingLocation
            )
            return overlay
        }()
        
        // MARK: Methods
        
        init() {
            // Updates the URL session challenge handler to use the
            // specified credentials and tokens for any challenges.
            ArcGISEnvironment.authenticationManager.arcGISAuthenticationChallengeHandler = ChallengeHandler()
        }
        
        deinit {
            // Resets the URL session challenge handler to use default handling.
            ArcGISEnvironment.authenticationManager.arcGISAuthenticationChallengeHandler = nil
        }
        
        /// Adds the provided utility element to the parameters of the pending trace and a corresponding
        /// starting location or barrier graphic to the map.
        /// - Parameters:
        ///   - element: The utility element to be added to the pending trace.
        ///   - point: The location on the map where the element's visual indicator should be added.
        ///
        /// Adding custom attributes to the graphic allows us to apply different rendering styles
        /// for starting point and barrier graphics.
        private func add(_ element: UtilityElement, at point: Geometry) {
            guard let pendingTraceParameters,
                  case .settingPoints(let pointType) = tracingActivity else { return }
            let graphic = Graphic(
                geometry: point,
                attributes: [String(describing: PointType.self): pointType.rawValue]
            )
            switch pointType {
            case.barrier:
                pendingTraceParameters.addBarrier(element)
            case .start:
                pendingTraceParameters.addStartingLocation(element)
            }
            points.addGraphic(graphic)
            lastAddedElement = element
        }
        
        /// Adds a provided feature to the pending trace.
        ///
        /// For junction features with more than one terminal, the user should be prompted to pick a
        /// terminal. For edge features, the fractional point along the feature's edge should be
        /// computed.
        /// - Parameters:
        ///   - feature: The feature to be added to the pending trace.
        ///   - mapPoint: The location on the map where the feature was discovered. If the feature is a
        ///   junction type, the feature's geometry will be used instead.
        func add(_ feature: ArcGISFeature, at mapPoint: Point) {
            if let element = network.makeElement(arcGISFeature: feature),
               let geometry = feature.geometry,
               let table = feature.table as? ArcGISFeatureTable,
               let networkSource = network.definition?.networkSource(named: table.tableName) {
                switch networkSource.kind {
                case .junction:
                    add(element, at: geometry)
                    if element.assetType.terminalConfiguration?.terminals.count ?? .zero > 1 {
                        terminalSelectorIsOpen.toggle()
                    }
                case .edge:
                    if let line = GeometryEngine.makeGeometry(from: geometry, z: nil) as? Polyline {
                        element.fractionAlongEdge = GeometryEngine.polyline(
                            line,
                            fractionalLengthClosestTo: mapPoint,
                            tolerance: -1
                        )
                        updateUserHint(
                            withMessage: String(format: "fractionAlongEdge: %.3f", element.fractionAlongEdge)
                        )
                        add(element, at: mapPoint)
                    }
                @unknown default:
                    return
                }
            } else {
                updateUserHint(withMessage: "An error occurred while adding element to the trace.")
            }
        }
        
        /// Sets the pending trace parameters with the provided trace type.
        /// - Parameter type: The trace type.
        func setTraceParameters(ofType type: UtilityTraceParameters.TraceType) {
            pendingTraceParameters = UtilityTraceParameters(
                traceType: type,
                startingLocations: []
            )
            pendingTraceParameters?.traceConfiguration = mediumVoltageRadial?.defaultTraceConfiguration
            tracingActivity = .settingPoints(pointType: .start)
        }
        
        /// Resets all of the important stateful values for when a trace is cancelled or completed.
        func reset() {
            map.operationalLayers.forEach { ($0 as? FeatureLayer)?.clearSelection() }
            points.removeAllGraphics()
            pendingTraceParameters = nil
            tracingActivity = .none
        }
        
        /// Performs important tasks including adding credentials, loading and adding operational layers.
        func setup() async {
            do {
                try await map.load()
                try await network.load()
            } catch {
                updateUserHint(withMessage: "An error occurred while loading the network.")
                return
            }
        }
        
        /// Runs a trace with the pending trace configuration and selects features in the map that
        /// correspond to the element results.
        ///
        /// - Note: Elements are grouped by network source prior to selection so that all selections
        /// per operational layer can be made at once.
        func trace() async throws {
            guard let pendingTraceParameters = pendingTraceParameters else { return }
            let traceResults = try await network
                .trace(using: pendingTraceParameters)
                .compactMap { $0 as? UtilityElementTraceResult }
            for result in traceResults {
                let groups = Dictionary(grouping: result.elements) { $0.networkSource.name }
                for (networkName, elements) in groups {
                    guard let layer = map.operationalLayers.first(
                        where: { ($0 as? FeatureLayer)?.featureTable?.tableName == networkName }
                    ) as? FeatureLayer else { continue }
                    let features = try await network.features(for: elements)
                    layer.selectFeatures(features)
                }
            }
        }
        
        /// Updates the textual user hint.
        ///
        /// If no message is provided a default hint is used.
        /// - Parameter message: The message to display to the user.
        func updateUserHint(withMessage message: String? = nil) {
            if let message {
                hint = message
            } else {
                switch tracingActivity {
                case .none:
                    hint = nil
                case .settingPoints(let pointType):
                    switch pointType {
                    case .start:
                        hint = "Tap on the map to add a start location."
                    case .barrier:
                        hint = "Tap on the map to add a barrier."
                    }
                case .traceCompleted:
                    hint = "Trace completed."
                case .traceFailed(let description):
                    hint = "Trace failed.\n\(description)"
                case .traceRunning:
                    hint = nil
                }
            }
        }
    }
}

private extension PortalItem {
    /// A web map portal item for the Naperville Electric Map.
    static func napervilleElectricNetwork() -> PortalItem {
        PortalItem(
            // Sample server 7 authentication required.
            portal: Portal(
                url: .samplePortal,
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

private extension SimpleMarkerSymbol {
    /// The symbol for barrier elements.
    static var barrier: SimpleMarkerSymbol {
        .init(style: .x, color: .red, size: 20)
    }
    
    /// The symbol for starting location elements.
    static var startingLocation: SimpleMarkerSymbol {
        .init(style: .cross, color: .green, size: 20)
    }
}

private extension URL {
    /// The server containing the data for this sample.
    static var sampleServer7: URL {
        URL(string: "https://sampleserver7.arcgisonline.com")!
    }
    
    /// The portal containing the data for this sample.
    static var samplePortal: URL {
        sampleServer7.appendingPathComponent("portal/sharing/rest")
    }
}
