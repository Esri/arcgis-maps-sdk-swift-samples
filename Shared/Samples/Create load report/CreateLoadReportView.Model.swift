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

extension CreateLoadReportView {
    fileprivate struct PhaseSummaries {
        private var storage = [ObjectIdentifier: PhaseSummary]()
        
        mutating func setSummary(_ summary: PhaseSummary, forPhase phase: CodedValue) {
            storage[ObjectIdentifier(phase)] = summary
        }
        
        mutating func summary(forPhase phase: CodedValue) -> PhaseSummary? {
            storage[ObjectIdentifier(phase)]
        }
        
        mutating func removeSummary(forPhase phase: CodedValue) {
            storage[ObjectIdentifier(phase)] = nil
        }
        
        mutating func removeAll() {
            storage.removeAll()
        }
    }
}

extension CreateLoadReportView {
    /// The model used to store the geo model and other expensive objects
    /// used in this view.
    @MainActor
    class Model: ObservableObject {
        // MARK: Properties
        /// The utility network for this sample.
        private let utilityNetwork = UtilityNetwork(url: .utilityNetwork)
        
        /// The initial conditional expression.
        private var initialExpression: UtilityTraceConditionalExpression?
        
        /// The trace parameters for creating load reports.
        private var traceParameters: UtilityTraceParameters?
        
        /// The network attributes for the comparison.
        private var phasesNetworkAttribute: UtilityNetworkAttribute?
        
        /// A list of possible phases populated from the network's attributes.
        /// By default, they are not included in the load report.
        @Published private(set) var excludedPhases = [CodedValue]()
        
        /// A list of phases that are included in the load report.
        @Published private(set) var includedPhases = [CodedValue]()
        
        /// A list of possible phases populated from the network's attributes.
        private var allPhases = [CodedValue]()
        
        /// The phase summaries in the load report.
        private var summaries = PhaseSummaries()
        
        /// A Boolean value indicating if the run button is enabled.
        @Published private(set) var runEnabled = false
        
        /// The status text to display to the user.
        @Published private(set) var statusText: String?
        
        /// A Boolean value indicating if the sample is authenticated.
        private var isAuthenticated: Bool {
            !ArcGISEnvironment.authenticationManager.arcGISCredentialStore.credentials.isEmpty
        }
        
        // MARK: Methods
        
        /// Performs important tasks including adding credentials, loading and adding operational layers.
        func setup() async throws {
            try await ArcGISEnvironment.authenticationManager.arcGISCredentialStore.add(.publicSample)
            try await loadUtilityNetwork()
        }
        
        /// Loads the utility network.
        private func loadUtilityNetwork() async throws {
            statusText = "Loading utility network…"
            try await utilityNetwork.load()
            statusText = nil
            
            guard let startingLocation = makeStartingLocation(),
                  // Get the base condition and trace configuration from a default tier.
                  let traceConfiguration = getTraceConfiguration() else { return }
            
            // Set the default expression.
            initialExpression = traceConfiguration.traversability?.barriers as? UtilityTraceConditionalExpression
            
            // Create downstream trace parameters with elements and function outputs.
            let traceParameters = UtilityTraceParameters(traceType: .downstream, startingLocations: [startingLocation])
            traceParameters.addResultTypes([.elements, .functionOutputs])
            
            guard let definition = utilityNetwork.definition else { return }
            // The service category for counting total customers.
            if let serviceCategory = definition.categories.first(where: { $0.name == "ServicePoint" }),
               // The load attribute for counting total load.
               let loadAttribute = definition.networkAttributes.first(where: { $0.name == "Service Load" }),
               // The phase attribute for getting total phase current load.
               let phasesNetworkAttribute = definition.networkAttributes.first(where: { $0.name == "Phases Current" }) {
                self.phasesNetworkAttribute = phasesNetworkAttribute
                // Get possible coded phase values from the attributes.
                if let domain = phasesNetworkAttribute.domain as? CodedValueDomain {
                    excludedPhases = domain.codedValues.sorted { $0.name < $1.name }
                    allPhases = excludedPhases
                }
                // Create a comparison to check the existence of service points.
                let serviceCategoryComparison = UtilityCategoryComparison(
                    category: serviceCategory,
                    operator: .exists
                )
                let addLoadAttributeFunction = UtilityTraceFunction(
                    functionType: .add,
                    networkAttribute: loadAttribute,
                    condition: serviceCategoryComparison
                )
                // Create function input and output condition.
                traceConfiguration.addFunction(addLoadAttributeFunction)
                traceConfiguration.outputCondition = serviceCategoryComparison
                // Set to false to ensure that service points with incorrect phasing
                // (which therefore act as barriers) are not counted with results.
                traceConfiguration.includesBarriers = false
                // Assign the trace configuration to trace parameters.
                traceParameters.traceConfiguration = traceConfiguration
                self.traceParameters = traceParameters
            }
        }
        
        /// When the utility network is loaded, create a `UtilityElement`
        /// from the asset type to use as the starting location for the trace.
        private func makeStartingLocation() -> UtilityElement? {
            // Constants for creating the default starting location.
            let networkSourceName = "Electric Distribution Device"
            let assetGroupName = "Circuit Breaker"
            let assetTypeName = "Three Phase"
            let terminalName = "Load"
            let globalID = UUID(uuidString: "1CAF7740-0BF4-4113-8DB2-654E18800028")!
            
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
        
        /// Gets the utility tier's trace configuration.
        private func getTraceConfiguration() -> UtilityTraceConfiguration? {
            // Get a default trace configuration from a tier in the network.
            utilityNetwork
                .definition?
                .domainNetwork(named: "ElectricDistribution")?
                .tier(named: "Medium Voltage Radial")?
                .defaultTraceConfiguration
        }
        
        func run() async throws {
            statusText = "Creating load report…"
            
            guard let phasesNetworkAttribute,
                  let initialExpression,
                  let traceParameters else { return }
            
            for phase in includedPhases {
                guard let phaseCode = phase.code else { continue }
                
                // Create a conditional expression.
                let phasesAttributeComparison = UtilityNetworkAttributeComparison(
                    networkAttribute: phasesNetworkAttribute,
                    operator: .doesNotIncludeAny,
                    value: phaseCode
                )!
                // Chain it with the base condition using an OR operator.
                traceParameters.traceConfiguration?.traversability?.barriers = UtilityTraceOrCondition(
                    leftExpression: initialExpression,
                    rightExpression: phasesAttributeComparison
                )
                
                let traceResults = try await utilityNetwork.trace(using: traceParameters)
                
                var totalCustomers = 0
                var totalLoad = 0
                
                for result in traceResults {
                    switch result {
                    case let elementResult as UtilityElementTraceResult:
                        // Get the unique customers count.
                        totalCustomers = Set(elementResult.elements.map(\.objectID)).count
                    case let functionResult as UtilityFunctionTraceResult:
                        // Get the total load with a function output.
                        totalLoad = Int(functionResult.functionOutputs[1].result as! Double)
                    default:
                        break
                    }
                }
                summaries.setSummary(
                    PhaseSummary(
                        totalCustomers: totalCustomers,
                        totalLoad: totalLoad
                    ),
                    forPhase: phase
                )
            }
            statusText = nil
        }
        
        func addPhase(_ phase: CodedValue) {
            includedPhases.append(phase)
            excludedPhases = excludedPhases.filter { $0.name != phase.name }
            sortPhases()
            runEnabled = true
        }
        
        func deletePhase(_ phase: CodedValue) {
            excludedPhases.append(phase)
            includedPhases = includedPhases.filter { $0.name != phase.name }
            sortPhases()
            summaries.removeSummary(forPhase: phase)
        }
        
        func deletePhase(atOffsets indexSet: IndexSet) {
            guard let index = indexSet.first else { return }
            deletePhase(includedPhases[index])
        }
        
        func sortPhases() {
            includedPhases.sort { $0.name < $1.name }
            excludedPhases.sort { $0.name < $1.name }
        }
        
        func summaryForPhase(_ phase: CodedValue) -> LocalizedStringKey {
            let format: IntegerFormatStyle<Int> = .number
            if let summary = summaries.summary(forPhase: phase) {
                return "C: \(summary.totalCustomers, format: format)  L: \(summary.totalLoad, format: format)"
            } else {
                return "N/A"
            }
        }
        
        deinit {
            ArcGISEnvironment.authenticationManager.arcGISCredentialStore.removeAll()
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

private extension CreateLoadReportView {
    /// A struct for the phase summary, which contains the total customers
    /// and total load for the phase.
    struct PhaseSummary {
        let totalCustomers: Int
        let totalLoad: Int
    }
}

private extension URL {
    /// The utility network for this sample.
    static var utilityNetwork: URL {
        URL(string: "https://sampleserver7.arcgisonline.com/server/rest/services/UtilityNetwork/NapervilleElectric/FeatureServer")!
    }
}
