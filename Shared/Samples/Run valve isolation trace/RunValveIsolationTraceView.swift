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

struct RunValveIsolationTraceView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    var body: some View {
        MapViewReader { mapViewProxy in
            MapView(
                map: model.map,
                graphicsOverlays: [model.parametersOverlay]
            )
            .onSingleTapGesture { screenPoint, mapPoint in
                model.lastSingleTap = (screenPoint, mapPoint)
            }
            .overlay(alignment: .top) {
                Text(model.statusText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(8)
                    .background(.ultraThinMaterial, ignoresSafeAreaEdges: .horizontal)
                    .multilineTextAlignment(.center)
            }
            .task{
                try? await model.setup()
                await mapViewProxy.setViewpointCenter(model.startingLocationPoint, scale: 3_000)
            }
            .task(id: model.lastSingleTap?.mapPoint) {
                guard let lastSingleTap = model.lastSingleTap else {
                    return
                }
                if let feature = try? await mapViewProxy.identifyLayers(
                    screenPoint: lastSingleTap.screenPoint,
                    tolerance: 10
                ).first?.geoElements.first as? ArcGISFeature {
                    model.addFilterBarrier(for: feature, at: lastSingleTap.mapPoint)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Toggle("Isolated\nFeatures", isOn: $model.includesIsolatedFeatures)
                        .toggleStyle(.switch)
                        .disabled(model.traceCompleted)
                    Spacer()
                    Menu(model.selectedCategory?.name ?? "Category") {
                        ForEach(model.filterBarrierCategories, id: \.self) { category in
                            Button(category.name) {
                                model.selectedCategory = category
                                model.statusText = "\(category.name) selected."
                            }
                        }
                    }
                    .disabled(model.traceCompleted)
                    Spacer()
                    Button {
                        if model.traceEnabled {
                            Task { try await model.trace() }
                        } else {
                            model.reset()
                            Task { await mapViewProxy.setViewpointCenter(model.startingLocationPoint, scale: 3_000) }
                        }
                    } label: {
                        Text(model.traceEnabled ? "Trace" : "Reset")
                    }.disabled((model.selectedCategory == nil && !model.traceEnabled) || model.hasFilterBarriers)
                }
            }
            .alert(
                "Select terminal",
                isPresented: $model.terminalSelectorIsOpen,
                actions: { terminalPickerButtons }
            )
            .overlay(alignment: .center) {
                if model.tracingActivity != .none {
                    VStack {
                        Text(model.tracingActivity.label)
                        ProgressView()
                            .progressViewStyle(.circular)
                    }
                    .padding(6)
                    .background(.thinMaterial)
                    .cornerRadius(10)
                }
            }
        }
    }
    
    /// Buttons for each the available terminals on the last added utility element.
    @ViewBuilder
    var terminalPickerButtons: some View {
        ForEach(model.lastAddedElement?.assetType.terminalConfiguration?.terminals ?? []) { terminal in
            Button(terminal.name) {
                model.lastAddedElement?.terminal = terminal
                model.terminalSelectorIsOpen = false
                model.addTerminal()
            }
        }
    }
}

private extension RunValveIsolationTraceView {
    /// The view model for this sample.
    class Model: ObservableObject {
        /// A map with a 'night time' street map style.
        let map = Map(basemapStyle: .arcGISStreetsNight)
        
        /// The utility network for this sample.
        private var utilityNetwork = UtilityNetwork(url: .featureServiceURL)
        
        /// The service geodatabase used to create the feature layer.
        private var serviceGeodatabase: ServiceGeodatabase!
        
        /// The service geodatabase feature layers.
        private var layers: [FeatureLayer] = []
        
        /// The last locations in the screen and map where a tap occurred.
        ///
        /// Monitoring these values allows for an asynchronous identification task when they change.
        @Published var lastSingleTap: (screenPoint: CGPoint, mapPoint: Point)?
        
        /// A Boolean value indicating whether to include isolated features in the
        /// trace results when used in conjunction with an isolation trace.
        @Published var includesIsolatedFeatures = true
        
        /// A Boolean value indicating whether the trace is completed.
        @Published var traceCompleted = false
        
        /// The current tracing related activity.
        @Published var tracingActivity: TracingActivity = .loadingServiceGeodatabase
        
        /// The point geometry of the starting location.
        @Published var startingLocationPoint: Point!
        
        /// The base trace parameters.
        @Published var traceParameters: UtilityTraceParameters = UtilityTraceParameters(traceType: .isolation, startingLocations: [])
        
        /// A Boolean value indicating if tracing is enabled.
        @Published var traceEnabled = true
        
        /// The status text to display to the user.
        @Published var statusText: String =  "Loading Utility Network…"
        
        /// The filter barrier categories.
        @Published var filterBarrierCategories: [UtilityCategory] = []
        
        /// The selected filter barrier category.
        @Published var selectedCategory: UtilityCategory? = nil
        
        var hasFilterBarriers: Bool {
            traceParameters.filterBarriers.isEmpty
        }
        
        /// A Boolean value indicating whether the terminal selection menu is open.
        ///
        /// When a utility element has more than one terminal, the user is presented with a menu of the
        /// available terminal names.
        @Published var terminalSelectorIsOpen = false
        
        /// The last element that was added to either the list of starting points or barriers.
        ///
        /// When an element contains more than one terminal, the user should be presented with the
        /// option to select a terminal. Keeping a reference to the last added element provides ease
        /// of access to save the user's choice.
        @Published var lastAddedElement: UtilityElement?
        
        /// The filter barrier identifer.
        static let filterBarrierIdentifier = "filter barrier"
        
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
        func setup() async throws {
            try await ArcGISEnvironment.authenticationManager.arcGISCredentialStore.add(.publicSample)
            try await loadServiceGeodatabase()
            try await loadUtilityNetwork()
        }
        
        /// Load the service geodatabase and initialize the layers.
        @MainActor
        func loadServiceGeodatabase() async throws {
            // Loads the geodatabase if it does not exist.
            if serviceGeodatabase == nil {
                serviceGeodatabase = ServiceGeodatabase(url: .featureServiceURL)
                try await serviceGeodatabase.load()
                tracingActivity = .loadingNetwork
            }
            
            // The gas device layer and gas line layer are created from the service geodatabase.
            if let gasDeviceLayerTable = serviceGeodatabase.table(withLayerID: 0),
               let gasLineLayerTable = serviceGeodatabase.table(withLayerID: 3) {
                let layers = [gasLineLayerTable, gasDeviceLayerTable].map(FeatureLayer.init)
                // Add the utility network feature layers to the map for display.
                map.addOperationalLayers(layers)
                self.layers = layers
            }
        }
        
        /// Load the utility network.
        @MainActor
        func loadUtilityNetwork() async throws {
            try? await utilityNetwork.load()
            statusText = """
                            Utility network loaded.
                            Tap on the map to add filter barriers or run the trace directly without filter barriers.
                        """
            tracingActivity = .startingLocation
            if let startingLocation = makeStartingLocation() {
                traceParameters.addStartingLocation(startingLocation)
                try await utilityNetwork.features(for: traceParameters.startingLocations).forEach { feature in
                    if let point = feature.geometry as? Point {
                        // Get the geometry of the starting location as a point.
                        // Then draw the starting location on the map.
                        
                        startingLocationPoint = point
                        addGraphic(for: startingLocationPoint, traceLocationType: "starting point")
                        tracingActivity = .none
                        
                        // Get available utility categories.
                        if utilityNetwork.definition != nil {
                            filterBarrierCategories = utilityNetwork.definition!.categories
                        }
                        
                    }
                }
            }
        }
        
        /// Adds a graphic to the graphics overlay.
        /// - Parameters:
        ///   - location: The `Point` location to place the graphic..
        ///   - traceLocationType: The textual description of the trace location type.
        func addGraphic(for location: Point, traceLocationType: String) {
            parametersOverlay.addGraphic(
                Graphic(geometry: location, attributes: ["TraceLocationType": traceLocationType], symbol: nil)
            )
        }
        
        /// When the utility network is loaded, create a`UtilityElement`
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
        
        /// Runs a trace with the pending trace configuration and selects features in the map that
        /// correspond to the element results.
        @MainActor
        func trace() async throws {
            tracingActivity = .runningTrace
            
            guard let configuration = makeTraceConfiguration(category: selectedCategory) else {
                statusText = "Failed to get trace configuration."
                return
            }
            traceParameters.traceConfiguration = configuration
            
            let traceResults = try await utilityNetwork
                .trace(using: traceParameters)
                .compactMap { $0 as? UtilityElementTraceResult }
            traceEnabled = false
            traceCompleted = true
            if traceParameters.filterBarriers.isEmpty {
                statusText = "Trace with \(selectedCategory!.name) cetegory completed."
            } else {
                statusText = "Trace with filter barriers completed."
            }
            tracingActivity = .none
            
            for result in traceResults {
                let groups = Dictionary(grouping: result.elements, by: \.networkSource.name)
                if groups.isEmpty {
                    statusText = "Trace completed with no output."
                }
                for (networkName, elements) in groups {
                    guard let layer = map.operationalLayers.first(
                        where: { ($0 as? FeatureLayer)?.featureTable?.tableName == networkName }
                    ) as? FeatureLayer else { continue }
                    let features = try await utilityNetwork.features(for: elements)
                    layer.selectFeatures(features)
                }
            }
        }
        
        /// Resets the state values for when a trace is cancelled or completed.
        func reset() {
            guard traceCompleted else { return }
            // Reset the trace if it is already completed.
            layers.forEach { $0.clearSelection() }
            traceParameters.removeAllBarriers()
            parametersOverlay.removeAllGraphics()
            traceCompleted = false
            selectedCategory = nil
            // Add back the starting location.
            addGraphic(for: startingLocationPoint, traceLocationType:  "starting point")
            traceEnabled = true
            statusText = "Tap on the map to add filter barriers, or run the trace directly without filter barriers."
        }
        
        /// Get the utility tier's trace configuration and apply category comparison.
        private func makeTraceConfiguration(category: UtilityCategory?) -> UtilityTraceConfiguration? {
            // Get a default trace configuration from a tier in the network.
            guard let configuration = utilityNetwork
                .definition?
                .domainNetwork(named: "Pipeline")?
                .tier(named: "Pipe Distribution System")?
                .defaultTraceConfiguration
            else { return nil }
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
            } else {
                configuration.filter = nil
            }
            configuration.includesIsolatedFeatures = includesIsolatedFeatures
            return configuration
        }
        
        /// Adds a graphic at the tapped location for the filter barrier.
        /// - Parameters:
        ///   - feature: The geo element retrieved as a `Feature`.
        ///   - location: The `Point` used to identify utility elements in the utility network.
        func addFilterBarrier(for feature: ArcGISFeature, at location: Point) {
            guard let geometry = feature.geometry,
                  let element = utilityNetwork.makeElement(arcGISFeature: feature) else { return }
            
            selectedCategory = filterBarrierCategories.first( where: { $0.name == "Isolating"} )
            
            switch element.networkSource.kind {
            case .junction:
                lastAddedElement = element
                if let terminals = element.assetType.terminalConfiguration?.terminals {
                    if terminals.count > 1 {
                        terminalSelectorIsOpen.toggle()
                        return
                    } else {
                        if let terminal = terminals.first {
                            statusText = "Juntion element with terminal \(terminal.name) added to the filter barriers."
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
                    statusText = String(format: "Edge element at fractionAlongEdge %.3f added to the filter barriers.", element.fractionAlongEdge)
                }
            }
            
            traceParameters.addFilterBarrier(element)
            lastAddedElement = element
            let point = geometry as? Point ?? location
            addGraphic(for: point, traceLocationType: RunValveIsolationTraceView.Model.filterBarrierIdentifier)
        }
        
        func addTerminal() {
            if let terminal = lastAddedElement?.terminal, let lastAddedElement, let lastSingleTap {
                traceParameters.addFilterBarrier(lastAddedElement)
                statusText = "Juntion element with terminal \(terminal.name) added to the filter barriers."
                addGraphic(for: lastSingleTap.mapPoint, traceLocationType: RunValveIsolationTraceView.Model.filterBarrierIdentifier)
            }
        }
        
        /// The different states of a utility network trace.
        enum TracingActivity: CaseIterable {
            case loadingServiceGeodatabase, loadingNetwork, startingLocation, runningTrace, none
            
            /// A human-readable label for the tracing activity.
            var label: String {
                switch self {
                case .loadingServiceGeodatabase: return "Loading service geodatabase…"
                case .loadingNetwork: return "Loading utility network…"
                case .startingLocation: return "Getting starting location feature…"
                case .runningTrace: return "Running isolation trace…"
                case .none: return ""
                }
            }
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

extension UtilityCategory: Equatable {
    public static func == (lhs: UtilityCategory, rhs: UtilityCategory) -> Bool {
        lhs.name == rhs.name
    }
}

extension UtilityCategory: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}
