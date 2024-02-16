// Copyright 2024 Esri
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

extension ValidateUtilityNetworkTopologyView {
    /// The view model for the sample.
    @MainActor
    class Model: ObservableObject {
        // MARK: Properties
        
        /// A map with no specified style.
        let map = Map()
        
        /// The graphics overlay for the starting location graphic.
        let graphicsOverlay: GraphicsOverlay = {
            let greenCrossSymbol = SimpleMarkerSymbol(style: .cross, color: .green, size: 25)
            let graphic = Graphic(symbol: greenCrossSymbol)
            return GraphicsOverlay(graphics: [graphic])
        }()
        
        /// The utility network for the sample.
        private var utilityNetwork: UtilityNetwork!
        
        /// The trace parameters for tracing with the utility network.
        private var traceParameters: UtilityTraceParameters!
        
        /// The feature currently being edited.
        private(set) var feature: ArcGISFeature?
        
        /// The feature's field currently being edited.
        private(set) var field: Field?
        
        /// The coded values from the field's domain.
        private(set) var fieldValueOptions: [CodedValue] = []
        
        /// The selected field coded value.
        @Published var selectedFieldValue: CodedValue?
        
        /// The text representing the current status.
        @Published var statusMessage = ""
        
        /// A Boolean value indicating whether the current state of the utility network can be obtained.
        @Published private(set) var canGetState = false
        
        /// A Boolean value indicating whether a trace can be run.
        @Published private(set) var canTrace = false
        
        /// A Boolean value indicating whether the utility network topology can be validated.
        @Published private(set) var canValidateNetworkTopology = false
        
        /// A Boolean value indicating whether there is a selection that can be cleared.
        @Published private(set) var canClearSelection = false
        
        deinit {
            ArcGISEnvironment.authenticationManager.arcGISCredentialStore.removeAll()
        }
        
        // MARK: Methods
        
        /// Gets the current state of the utility network and updates the status with the results.
        func getState() async throws {
            statusMessage = "Getting utility network state…"
            
            // Get the current state of the utility network.
            let state = try await utilityNetwork.state
            
            // Allow validating if the network contains any dirty areas or errors.
            canValidateNetworkTopology = state.hasDirtyAreas || state.hasErrors
            
            // Allow tracing if the network has topology is enabled.
            canTrace = state.networkTopologyIsEnabled
            
            // Update the status with the state.
            let instructionMessage = canValidateNetworkTopology
            ? "Tap 'Validate' before trace or expect a trace error."
            : "Tap on a feature to edit or tap 'Trace' to run a trace."
            
            statusMessage = """
            Utility Network State:
            Has dirty areas: \(state.hasDirtyAreas)
            Has errors: \(state.hasErrors)
            Network topology is enabled: \(state.networkTopologyIsEnabled)
            \(instructionMessage)
            """
        }
        
        /// Runs a trace and selects features in the map that correspond to the resulting elements.
        func trace() async throws {
            statusMessage = "Running a downstream trace…"
            clearLayerSelections()
            
            // Get the element trace result from the utility network using the trace parameters.
            let traceResults = try await utilityNetwork.trace(using: traceParameters)
            guard let elementTraceResult = traceResults.first(where: { $0 is UtilityElementTraceResult })
                    as? UtilityElementTraceResult else { return }
            
            // Select all of elements found.
            statusMessage = "Selecting found elements…"
            
            for layer in map.operationalLayers.compactMap({ $0 as? FeatureLayer }) {
                let layerElements = elementTraceResult.elements.filter { element in
                    element.networkSource.featureTable.tableName == layer.featureTable?.tableName
                }
                
                if !layerElements.isEmpty {
                    let features = try await utilityNetwork.features(for: layerElements)
                    layer.selectFeatures(features)
                }
            }
            canClearSelection = true
            
            statusMessage = "Trace completed: \(elementTraceResult.elements.count) elements found."
        }
        
        /// Validates the utility network topology within a given extent and updates the status with the results.
        func validate(forExtent extent: Envelope) async throws {
            statusMessage = "Validating utility network topology…"
            
            // Validate the utility network topology with the extent.
            let job = utilityNetwork.validateNetworkTopology(forExtent: extent)
            job.start()
            let result = try await job.result.get()
            
            // Update the status with the result.
            canValidateNetworkTopology = result.hasDirtyAreas
            statusMessage = """
            Network Validation Result
            Has dirty areas: \(result.hasDirtyAreas)
            Has errors: \(result.hasErrors)
            Tap 'Get State' to check the updated network state.
            """
        }
        
        /// Selects a feature from a given list of identify layer results.
        /// - Parameter identifyResults: The identify layer results.
        func selectFeature(from identifyResults: [IdentifyLayerResult]) {
            clearSelection()
            
            // Get the first feature from the results.
            let layerResult = identifyResults.first {
                let layerName = $0.layerContent.name
                return layerName == .deviceTableName || layerName == .lineTableName
            }
            guard let feature = layerResult?.geoElements.first as? ArcGISFeature else { return }
            
            // Get the coded values from the feature's field.
            let fieldName: String = feature.table?.tableName == .deviceTableName
            ? .deviceStatusField
            : .nominalVoltageField
            
            guard let field = feature.table?.field(named: fieldName),
                  let codedValues = (field.domain as? CodedValueDomain)?.codedValues else { return }
            self.field = field
            fieldValueOptions = codedValues
            
            // Get the current attribute value from the feature.
            let fieldValue = feature.attributes[field.name]
            selectedFieldValue = codedValues.first { valuesAreEqual($0.code, fieldValue) }
            
            // Select the identified feature.
            let featureLayer = feature.table?.layer as? FeatureLayer
            featureLayer?.selectFeature(feature)
            canClearSelection = true
            self.feature = feature
            
            statusMessage = "Select a new '\(field.alias)'."
        }
        
        /// Applies the edits to the feature to the service.
        func applyEdits() async throws {
            guard let feature,
                  let serviceFeatureTable = feature.table as? ServiceFeatureTable,
                  let serviceGeodatabase = serviceFeatureTable.serviceGeodatabase,
                  let fieldName = field?.name else { return }
            
            // Update the feature with the new value in the it's feature table.
            statusMessage = "Updating feature…"
            feature.setAttributeValue(selectedFieldValue?.code, forKey: fieldName)
            try await serviceFeatureTable.update(feature)
            
            // Apply the edits in the feature table to the service.
            statusMessage = "Applying edits…"
            let featureTableEditResults = try await serviceGeodatabase.applyEdits()
            
            // Determine if the attempt to edit resulted in any errors.
            let didCompleteSuccessfully = featureTableEditResults.allSatisfy { tableEditResult in
                tableEditResult.editResults.allSatisfy { featureEditResult in
                    !featureEditResult.didCompleteWithErrors
                }
            }
            
            // Update the status with the results.
            canValidateNetworkTopology = true
            statusMessage = didCompleteSuccessfully ? """
            Edits applied successfully.
            Tap 'Get State' to check the updated network state.
            """
            : "Apply edits completed with error."
        }
        
        /// Clears the selected feature(s).
        func clearSelection() {
            clearLayerSelections()
            feature = nil
            canClearSelection = false
        }
        
        // MARK: Setup
        
        /// Performs setup tasks such as adding credentials, loading the utility network, and setting up the trace parameters.
        func setup() async throws {
            // Add the credential to access the web map.
            try await ArcGISEnvironment.authenticationManager.arcGISCredentialStore.add(.publicSample)
            
            try await setupMap()
            try await setupUtilityNetwork()
            try await setupTraceParameters()
            
            // Set the initial states using utility network's capabilities.
            guard let utilityNetworkCapabilities = utilityNetwork.definition?.capabilities else { return }
            canGetState = utilityNetworkCapabilities.supportsNetworkState
            canTrace = utilityNetworkCapabilities.supportsTrace
            canValidateNetworkTopology = utilityNetworkCapabilities.supportsValidateNetworkTopology
            canClearSelection = false
            
            statusMessage = """
            Utility Network Loaded
            Tap on a feature to edit.
            Tap 'Get State' to check if validating is necessary or if tracing is available.
            Tap 'Trace' to run a trace.
            """
        }
        
        /// Sets up and loads the web map.
        private func setupMap() async throws {
            statusMessage = "Loading web map…"
            
            // Create a portal item using the portal and id for the Naperville Electric web map.
            let portal = Portal(url: .sampleServerPortal, connection: .authenticated)
            let portalItem = PortalItem(portal: portal, id: .napervilleElectric)
            
            // Set the portal item to the map and load the map.
            map.item = portalItem
            map.initialViewpoint = Viewpoint(center: Point(x: -9815160, y: 5128880), scale: 3640)
            try await map.load()
            
            // Set the map to load in persistent session mode (workaround for server caching issue).
            // https://support.esri.com/en-us/bug/asynchronous-validate-request-for-utility-network-servi-bug-000160443
            map.loadSettings.featureServiceSessionType = .persistent
            
            // Add labels to the map to visualize attribute editing.
            addLabels(to: .deviceTableName, for: .deviceStatusField, color: .blue)
            addLabels(to: .lineTableName, for: .nominalVoltageField, color: .red)
        }
        
        /// Loads the utility network and switches to a new version on the service.
        private func setupUtilityNetwork() async throws {
            statusMessage = "Loading utility network…"
            
            // Get the utility network from the map.
            utilityNetwork = map.utilityNetworks.first
            try await utilityNetwork.load()
            
            // Create service version parameters to restrict editing and tracing on a random branch.
            let uniqueString = UUID().uuidString
            let parameters = ServiceVersionParameters()
            parameters.name = "ValidateNetworkTopology_\(uniqueString)"
            parameters.description = "Validate network topology with ArcGIS Maps SDK."
            parameters.access = .private
            
            // Create and switch to a new version on the service geodatabase using the parameters.
            let serviceGeodatabase = utilityNetwork.serviceGeodatabase!
            let serviceVersionInfo = try await serviceGeodatabase.makeVersion(parameters: parameters)
            try await serviceGeodatabase.switchToVersion(named: serviceVersionInfo.name)
            
            // Add the dirty area table to the map to visualize it.
            guard let dirtyAreaTable = utilityNetwork.dirtyAreaTable else { return }
            try await dirtyAreaTable.load()
            let featureLayer = FeatureLayer(featureTable: dirtyAreaTable)
            map.addOperationalLayer(featureLayer)
        }
        
        /// Sets up the starting location and trace parameters for tracing.
        private func setupTraceParameters() async throws {
            statusMessage = "Loading starting location…"
            
            // Constants for creating the starting location and trace parameters.
            let assetGroupName = "Circuit Breaker"
            let assetTypeName = "Three Phase"
            let domainNetworkName = "ElectricDistribution"
            let tierName = "Medium Voltage Radial"
            
            // Create the default starting location using the utility network.
            guard let networkSource = utilityNetwork.definition?.networkSource(named: .deviceTableName),
                  let assetGroup = networkSource.assetGroup(named: assetGroupName),
                  let assetType = assetGroup.assetType(named: assetTypeName),
                  let startingLocation = utilityNetwork.makeElement(
                    assetType: assetType,
                    globalID: .globalID
                  ) else { return }
            
            // Set the terminal for the location, in our case, the "Load" terminal.
            let terminal = startingLocation.assetType.terminalConfiguration?.terminals.first {
                $0.name == "Load"
            }
            startingLocation.terminal = terminal
            
            // Add a graphic to indicate the location on the map.
            let startFeature = try await utilityNetwork.features(for: [startingLocation]).first
            graphicsOverlay.graphics.first?.geometry = startFeature?.geometry
            
            // Create downstream trace parameters for the location.
            traceParameters = UtilityTraceParameters(
                traceType: .downstream,
                startingLocations: [startingLocation]
            )
            
            // Set the configuration to stop traversing on an open device.
            let domainNetwork = utilityNetwork?.definition?.domainNetwork(named: domainNetworkName)
            let sourceTier = domainNetwork?.tier(named: tierName)
            traceParameters?.traceConfiguration = sourceTier?.defaultTraceConfiguration
        }
        
        // MARK: Helpers
        
        /// Clears the selections for all of the map's operational layers..
        private func clearLayerSelections() {
            for layer in map.operationalLayers.compactMap({ $0 as? FeatureLayer }) {
                layer.clearSelection()
            }
        }
        
        /// Adds labels for a given field name to a layer with a given name.
        /// - Parameters:
        ///   - layerName: The name of the layer on the map to display the labels on.
        ///   - fieldName: The name of the field to display in the labels.
        ///   - color: The color of the label's text.
        private func addLabels(to layerName: String, for fieldName: String, color: UIColor) {
            // Create a expression for the label using the given field name.
            let expression = SimpleLabelExpression(simpleExpression: "[\(fieldName)]")
            
            // Create a symbol for label's text using the given color.
            let symbol = TextSymbol(color: color, size: 12)
            symbol.haloColor = .white
            symbol.haloWidth = 2
            
            // Create the definition from the expression and text symbol
            let definition = LabelDefinition(labelExpression: expression, textSymbol: symbol)
            
            // Add the definition to the map layer with the given layer name.
            let layer = self.map.operationalLayers.first { $0.name == layerName } as? FeatureLayer
            layer?.addLabelDefinition(definition)
            layer?.labelsAreEnabled = true
        }
        
        /// Determines whether the values of two `Any` types are equal.
        /// - Parameters:
        ///   - lhs: The left hand side value.
        ///   - rhs: The right hand side value.
        /// - Returns: A Boolean value indicating whether the values are equal.
        private func valuesAreEqual(_ lhs: Any?, _ rhs: Any?) -> Bool {
            guard let lhs = lhs as? any Equatable,
                  let rhs = rhs as? any Equatable else { return false }
            
            return lhs.isEqual(to: rhs) || rhs.isEqual(to: lhs)
        }
    }
}

// MARK: Extensions

private extension Equatable {
    /// Determines whether a given equatable is equal.
    /// - Parameter other: The value to compare.
    /// - Returns: A Boolean value indicating whether the value is equal.
    func isEqual(to other: any Equatable) -> Bool {
        guard let other = other as? Self else { return false }
        return self == other
    }
}

private extension String {
    /// The name of the "Electric Distribution Device" feature table.
    static let deviceTableName = "Electric Distribution Device"
    
    /// The name of the device status field in the "Electric Distribution Device" feature table.
    static let deviceStatusField = "devicestatus"
    
    /// The name of the "Electric Distribution Line" feature table.
    static let lineTableName = "Electric Distribution Line"
    
    /// The name of the nominal voltage field in the "Electric Distribution Line" feature table.
    static let nominalVoltageField = "nominalvoltage"
}

private extension UUID {
    /// The global ID of the feature from which the starting location is created.
    static var globalID: UUID {
        UUID(uuidString: "1CAF7740-0BF4-4113-8DB2-654E18800028")!
    }
}

private extension URL {
    /// The URL for the sample server 7 portal.
    static var sampleServerPortal: URL {
        URL(string: "https://sampleserver7.arcgisonline.com/portal/sharing/rest")!
    }
}

private extension PortalItem.ID {
    /// The ID for the "Naperville Electric" portal item on sample server 7.
    static var napervilleElectric: Self {
        Self("6e3fc6db3d0b4e6589eb4097eb3e5b9b")!
    }
}

private extension ArcGISCredential {
    /// The public credentials for the data in this sample.
    /// - Note: Never hardcode login information in a production application. This is done solely for the sake of the sample.
    static var publicSample: ArcGISCredential {
        get async throws {
            try await TokenCredential.credential(
                for: .sampleServerPortal,
                username: "editor01",
                password: "S7#i2LWmYH75"
            )
        }
    }
}
