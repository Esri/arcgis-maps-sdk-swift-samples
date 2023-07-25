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
import Foundation

extension RunValveIsolationTraceView {
    /// The view model for this sample.
    @MainActor
    class Model: ObservableObject {
        /// A map with a 'night time' street map style.
        let map = Map(basemapStyle: .arcGISStreetsNight)
        
        /// The utility network for this sample.
        private let utilityNetwork = UtilityNetwork(url: .featureServiceURL)
        
        /// The service geodatabase used to create the feature layer.
        private let serviceGeodatabase = ServiceGeodatabase(url: .featureServiceURL)
        
        /// The service geodatabase feature layers.
        private var layers: [FeatureLayer] = []
        
        /// The last element that was added to the list of filter barriers.
        ///
        /// When an element contains more than one terminal, the user should be presented with the
        /// option to select a terminal. Keeping a reference to the last added element provides ease
        /// of access to save the user's choice.
        @Published private(set) var lastAddedElement: UtilityElement?
        
        /// The current tracing related activity.
        @Published private(set) var tracingActivity: TracingActivity? = .loadingServiceGeodatabase
        
        /// The base trace parameters.
        private let traceParameters = UtilityTraceParameters(traceType: .isolation, startingLocations: [])
        
        /// The point geometry of the starting location.
        private(set) var startingLocationPoint: Point?
        
        /// The filter barrier categories.
        private(set) var filterBarrierCategories: [UtilityCategory] = []
        
        /// The selected filter barrier category.
        @Published private(set) var selectedCategory: UtilityCategory?
        
        /// A Boolean value indicating if tracing is enabled.
        @Published private(set) var traceEnabled = false
        
        /// A Boolean value indicating if the reseting the trace is enabled.
        @Published private(set) var resetEnabled = false
        
        /// A Boolean value indicating if the user has added filter barriers to the trace parameters.
        private var hasFilterBarriers: Bool { !traceParameters.filterBarriers.isEmpty }
        
        /// A Boolean value indicating whether the terminal selection menu is open.
        @Published var terminalSelectorIsOpen = false
        
        /// The status text to display to the user.
        @Published var statusText: String = "Loading Utility Network…"
        
        /// The filter barrier identifier.
        private static let filterBarrierIdentifier = "filter barrier"
        
        /// The graphic overlay to display starting location and filter barriers.
        let parametersOverlay: GraphicsOverlay = {
            let barrierPointSymbol = SimpleMarkerSymbol(style: .x, color: .red, size: 20)
            let barrierUniqueValue = UniqueValue(
                description: "Filter Barrier",
                label: "Filter Barrier",
                symbol: barrierPointSymbol,
                values: [filterBarrierIdentifier]
            )
            let startingPointSymbol = SimpleMarkerSymbol(style: .cross, color: .green, size: 20)
            let renderer = UniqueValueRenderer(
                fieldNames: ["TraceLocationType"],
                uniqueValues: [barrierUniqueValue],
                defaultLabel: "Starting Location",
                defaultSymbol: startingPointSymbol
            )
            let overlay = GraphicsOverlay()
            overlay.renderer = renderer
            return overlay
        }()
        
        init() {
            map.addUtilityNetwork(utilityNetwork)
        }
        
        deinit {
            ArcGISEnvironment.authenticationManager.arcGISCredentialStore.removeAll()
        }
        
        /// Performs important tasks including adding credentials, loading and adding operational layers.
        func setup() async {
            do {
                try await ArcGISEnvironment.authenticationManager.arcGISCredentialStore.add(.publicSample)
                try await loadServiceGeodatabase()
                try await loadUtilityNetwork()
            } catch {
                statusText = error.localizedDescription
            }
        }
        
        /// Loads the service geodatabase and initialize the layers.
        private func loadServiceGeodatabase() async throws {
            tracingActivity = .loadingServiceGeodatabase
            defer { tracingActivity = nil }
            try await serviceGeodatabase.load()
            
            // The gas device layer and gas line layer are created from the service geodatabase.
            if let gasDeviceLayerTable = serviceGeodatabase.table(withLayerID: 0),
               let gasLineLayerTable = serviceGeodatabase.table(withLayerID: 3) {
                let layers = [gasLineLayerTable, gasDeviceLayerTable].map(FeatureLayer.init)
                // Add the utility network feature layers to the map for display.
                map.addOperationalLayers(layers)
                self.layers = layers
            }
        }
        
        /// Loads the utility network.
        private func loadUtilityNetwork() async throws {
            tracingActivity = .loadingNetwork
            defer { tracingActivity = nil }
            try await utilityNetwork.load()
            statusText = """
                           Tap on the map to add filter barriers or run the trace \
                           directly without filter barriers by specifying a category \
                           through the Configuration menu.
                           """
            tracingActivity = .startingLocation
            guard let startingLocation = makeStartingLocation() else { return }
            traceParameters.addStartingLocation(startingLocation)
            if let feature = try await utilityNetwork.features(for: traceParameters.startingLocations).first,
               let point = feature.geometry as? Point {
                // Get the geometry of the starting location as a point.
                // Then draw the starting location on the map.
                
                addGraphic(for: point, traceLocationType: "starting point")
                startingLocationPoint = point
                tracingActivity = .none
                
                // Get available utility categories.
                if let definition = utilityNetwork.definition {
                    filterBarrierCategories = definition.categories
                }
            }
        }
        
        /// When the utility network is loaded, create a `UtilityElement`
        /// from the asset type to use as the starting location for the trace.
        private func makeStartingLocation() -> UtilityElement? {
            // Constants for creating the default starting location.
            let networkSourceName = "Gas Device"
            let assetGroupName = "Meter"
            let assetTypeName = "Customer"
            let terminalName = "Load"
            let globalID = UUID(uuidString: "98A06E95-70BE-43E7-91B7-E34C9D3CB9FF")!
            
            // Create a default starting location.
            if let networkSource = utilityNetwork.definition?.networkSource(named: networkSourceName),
               let assetType = networkSource.assetGroup(named: assetGroupName)?.assetType(named: assetTypeName),
               let startingLocation = utilityNetwork.makeElement(assetType: assetType, globalID: globalID) {
                // Set the terminal for the location. (For our case, use the "Load" terminal.)
                startingLocation.terminal = assetType.terminalConfiguration?.terminals.first(where: { $0.name == terminalName })
                return startingLocation
            } else {
                return nil
            }
        }
        
        /// Adds a graphic to the graphics overlay.
        /// - Parameters:
        ///   - location: The `Point` location to place the graphic.
        ///   - traceLocationType: The textual description of the trace location type.
        private func addGraphic(for location: Point, traceLocationType: String) {
            let graphic = Graphic(
                geometry: location,
                attributes: ["TraceLocationType": traceLocationType]
            )
            parametersOverlay.addGraphic(graphic)
        }
        
        /// Sets the selected filter barrier category and updates the status text.
        func selectCategory(_ category: UtilityCategory) {
            selectedCategory = category
            statusText = "\(category.name) selected."
            traceEnabled = true
        }
        
        /// Unselects the selected filter barrier category and updates the status text.
        func unselectCategory(_ category: UtilityCategory) {
            selectedCategory = nil
            traceEnabled = hasFilterBarriers
            statusText = "Tap on the map to add filter barriers, or run the trace directly without filter barriers."
        }
        
        /// Runs a trace with the pending trace configuration and selects features in the map that
        /// correspond to the element results.
        func trace(includeIsolatedFeatures: Bool) async {
            // Clear previous trace results.
            layers.forEach { $0.clearSelection() }
            
            tracingActivity = .runningTrace
            traceEnabled = false
            
            let configuration = makeTraceConfiguration(category: selectedCategory, includeIsolatedFeatures: includeIsolatedFeatures)
            traceParameters.traceConfiguration = configuration
            do {
                let traceResults = try await utilityNetwork
                    .trace(using: traceParameters)
                    .compactMap { $0 as? UtilityElementTraceResult }
                try await handleTraceResults(traceResults)
            } catch {
                statusText = "Trace failed."
                traceEnabled = true
                return
            }
            tracingActivity = .none
            traceEnabled = true
            resetEnabled = true
        }
        
        func handleTraceResults(_ traceResults: [UtilityElementTraceResult]) async throws {
            let elements = traceResults.flatMap(\.elements)
            guard !elements.isEmpty else {
                statusText = "Trace completed with no output."
                return
            }
            
            let groups = Dictionary(grouping: elements, by: \.networkSource.name)
            if groups.isEmpty {
                statusText = "Trace completed with no output."
                return
            }
            do {
                for (networkName, elements) in groups {
                    guard let layer = map.operationalLayers.first(
                        where: { ($0 as? FeatureLayer)?.featureTable?.tableName == networkName }
                    ) as? FeatureLayer else { continue }
                    let features = try await utilityNetwork.features(for: elements)
                    layer.selectFeatures(features)
                }
            } catch {
                statusText = error.localizedDescription
            }
            if !hasFilterBarriers, let selectedCategory {
                statusText = "Trace with \(selectedCategory.name.lowercased()) category completed."
            } else {
                statusText = "Trace with filter barriers completed."
            }
        }
        
        /// Removes all added filter barriers.
        func reset() {
            layers.forEach { $0.clearSelection() }
            traceParameters.removeAllFilterBarriers()
            parametersOverlay.removeAllGraphics()
            // Add back the starting location.
            if let startingLocationPoint {
                addGraphic(for: startingLocationPoint, traceLocationType: "starting point")
            }
            statusText = "Tap on the map to add filter barriers, or run the trace directly without filter barriers."
            resetEnabled = false
        }
        
        /// Gets the utility tier's trace configuration and apply category comparison.
        private func makeTraceConfiguration(category: UtilityCategory?, includeIsolatedFeatures: Bool) -> UtilityTraceConfiguration {
            // Get a default trace configuration from a tier in the network.
            guard let configuration = utilityNetwork
                .definition?
                .domainNetwork(named: "Pipeline")?
                .tier(named: "Pipe Distribution System")?
                .defaultTraceConfiguration
            else { fatalError("Utility network does not have a default trace configuration.") }
            if let category = category {
                // Note: `UtilityNetworkAttributeComparison` or `UtilityCategoryComparison`
                // with `UtilityCategoryComparisonOperator.doesNotExist` can also be used.
                // These conditions can be joined with either `UtilityTraceOrCondition`
                // or `UtilityTraceAndCondition`.
                // See more in the README.
                let comparison = UtilityCategoryComparison(category: category, operator: .exists)
                // Create a trace filter.
                let filter = UtilityTraceFilter()
                filter.barriers = comparison
                configuration.filter = filter
            }
            configuration.includesIsolatedFeatures = includeIsolatedFeatures
            return configuration
        }
        
        /// Adds a graphic at the tapped location for the filter barrier.
        /// - Parameters:
        ///   - feature: The geo element retrieved as a `Feature`.
        ///   - location: The `Point` used to identify utility elements in the utility network.
        func addFilterBarrier(for feature: ArcGISFeature, at location: Point) {
            guard let geometry = feature.geometry,
                  let element = utilityNetwork.makeElement(arcGISFeature: feature) else {
                return
            }
            
            switch element.networkSource.kind {
            case .junction:
                lastAddedElement = element
                if let terminals = element.assetType.terminalConfiguration?.terminals {
                    if terminals.count > 1 {
                        terminalSelectorIsOpen.toggle()
                        return
                    } else {
                        if let terminal = terminals.first {
                            statusText = "Junction element with terminal \(terminal.name) added to the filter barriers."
                        }
                    }
                }
            case .edge:
                if let line = GeometryEngine.makeGeometry(from: geometry, z: nil) as? Polyline {
                    element.fractionAlongEdge = GeometryEngine.polyline(
                        line,
                        fractionalLengthClosestTo: location,
                        tolerance: -1
                    )
                    statusText = String(format: "Edge element at distance %.3f along edge added to the filter barriers.", element.fractionAlongEdge)
                }
            @unknown default:
                return
            }
            
            traceParameters.addFilterBarrier(element)
            lastAddedElement = element
            let point = geometry as? Point ?? location
            addGraphic(for: point, traceLocationType: RunValveIsolationTraceView.Model.filterBarrierIdentifier)
            resetEnabled = true
            traceEnabled = true
        }
        
        /// Adds the filter barrier of the user selected terminal to the trace parameters.
        func addTerminal(to point: Point) {
            guard let lastAddedElement, let terminal = lastAddedElement.terminal else { return }
            traceParameters.addFilterBarrier(lastAddedElement)
            statusText = "Junction element with terminal \(terminal.name) added to the filter barriers."
            resetEnabled = true
            addGraphic(
                for: point,
                traceLocationType: RunValveIsolationTraceView.Model.filterBarrierIdentifier
            )
        }
    }
}

extension RunValveIsolationTraceView.Model {
    /// The different states of a utility network trace.
    enum TracingActivity: CaseIterable {
        case loadingServiceGeodatabase,
             loadingNetwork,
             startingLocation,
             runningTrace
    }
}

private extension ArcGISCredential {
    /// The public credentials for the data in this sample.
    /// - Note: Never hardcode login information in a production application. This is done solely
    /// for the sake of the sample.
    static var publicSample: ArcGISCredential {
        get async throws {
            try await TokenCredential.credential(
                for: .featureServiceURL,
                username: "viewer01",
                password: "I68VGU^nMurF"
            )
        }
    }
}

private extension URL {
    /// The URL to the feature service for running the isolation trace.
    static var featureServiceURL: URL {
        URL(string: "https://sampleserver7.arcgisonline.com/server/rest/services/UtilityNetwork/NapervilleGas/FeatureServer")!
    }
}
