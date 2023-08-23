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

extension AnalyzeNetworkWithSubnetworkTraceView {
    /// The view model for this sample.
    @MainActor
    class Model: ObservableObject {
        /// A feature service for an electric utility network in Naperville, Illinois.
        private let utilityNetwork = UtilityNetwork(url: .featureServiceURL)
        
        /// An array of condition expressions.
        private var traceConditionalExpressions: [UtilityTraceConditionalExpression] = []
        
        /// An array of string representations of condition expressions.
        @Published private(set) var conditions: [String] = []
        
        /// The utility element to start the trace from.
        private var startingLocation: UtilityElement?
        
        /// The initial conditional expression.
        private var initialExpression: UtilityTraceConditionalExpression?
        
        /// The trace configuration.
        private var configuration: UtilityTraceConfiguration?
        
        /// A chained expression string.
        var expressionString: String {
            if let expression = chainExpressions(traceConditionalExpressions) {
                return string(for: expression)
            } else {
                return "Expressions failed to convert to string."
            }
        }
        
        /// An array of possible network attributes.
        @Published private(set) var possibleAttributes: [UtilityNetworkAttribute] = []
        
        /// A Boolean value indicating if running the trace is enabled.
        @Published private(set) var traceEnabled = false
        
        /// The status text to display to the user.
        @Published private(set) var statusText: String = "Loading utility network…"
        
        /// The number of trace results from a trace.
        @Published private(set) var traceResultsCount = 0
        
        /// A Boolean value indicating if the sample has been setup.
        @Published private(set) var isSetUp = false
        
        deinit {
            ArcGISEnvironment.authenticationManager.arcGISCredentialStore.removeAll()
        }
        
        // MARK: Methods
        
        /// Performs important tasks including adding credentials, loading utility network and setting trace parameters.
        func setup() async throws {
            do {
                try await ArcGISEnvironment.authenticationManager.arcGISCredentialStore.add(.publicSample)
                try await setupTraceParameters()
            } catch {
                throw error
            }
        }
        
        /// Loads the utility network and sets the trace parameters and other information
        /// used for running this sample.
        private func setupTraceParameters() async throws {
            defer { statusText = "" }
            
            // Constants for creating the default trace configuration.
            let domainNetworkName = "ElectricDistribution"
            let tierName = "Medium Voltage Radial"
            
            // Load the utility network.
            try await utilityNetwork.load()
            
            // Create a default starting location.
            let startingLocation = try makeStartingLocation()
            self.startingLocation = startingLocation
            
            guard let domainNetwork = utilityNetwork.definition?.domainNetwork(named: domainNetworkName),
                  let utilityTierConfiguration = domainNetwork.tier(named: tierName)?.defaultTraceConfiguration else {
                throw SetupError()
            }
            
            // Set the traversability.
            if utilityTierConfiguration.traversability == nil {
                utilityTierConfiguration.traversability = UtilityTraversability()
            }
            
            // Set the default expression (if provided).
            guard let expression = utilityTierConfiguration.traversability?.barriers as? UtilityTraceConditionalExpression else {
                throw SetupError()
            }
            self.initialExpression = expression
            
            if !traceConditionalExpressions.contains(where: { $0 === expression }) {
                traceConditionalExpressions.append(expression)
                conditions.append(string(for: expression))
            }
            
            // Set the traversability scope.
            utilityTierConfiguration.traversability?.scope = .junctions
            if let attributes = utilityNetwork.definition?.networkAttributes.filter({ !$0.systemIsDefined }) {
                possibleAttributes = attributes
            }
            
            self.configuration = utilityTierConfiguration
            traceEnabled = true
            isSetUp = true
        }
        
        /// When the utility network is loaded, creates a `UtilityElement`
        /// from the asset type to use as the starting location for the trace.
        private func makeStartingLocation() throws -> UtilityElement {
            // Constants for creating the default starting location.
            let deviceTableName = "Electric Distribution Device"
            let assetGroupName = "Circuit Breaker"
            let assetTypeName = "Three Phase"
            let globalID = UUID(uuidString: "1CAF7740-0BF4-4113-8DB2-654E18800028")!
            
            // Create a default starting location.
            guard let networkSource = self.utilityNetwork.definition?.networkSource(named: deviceTableName),
                  let assetType = networkSource.assetGroup(named: assetGroupName)?.assetType(named: assetTypeName),
                  let startingLocation = utilityNetwork.makeElement(assetType: assetType, globalID: globalID) else {
                throw SetupError()
            }
            // Set the terminal for this location. (For our case, use the "Load" terminal.)
            startingLocation.terminal = startingLocation.assetType.terminalConfiguration?.terminals.first(where: { $0.name == "Load" })
            return startingLocation
        }
        
        /// Runs a trace with the pending trace configuration.
        /// - Parameters:
        ///   - includeBarriers: A Boolean value indicating whether to include barriers in the trace results.
        ///   - includeContainers: A Boolean value indicating whether to include containment features in the trace results.
        /// - Precondition: `startingLocation` and `configuration`are not `nil`.
        func trace(includeBarriers: Bool, includeContainers: Bool) async throws {
            defer { statusText = "" }
            defer { traceEnabled = true }
            traceEnabled = false
            statusText = "Tracing…"
            guard let location = startingLocation else { preconditionFailure() }
            
            // Create utility trace parameters for the starting location.
            let parameters = UtilityTraceParameters(traceType: .subnetwork, startingLocations: [location])
            
            guard let configuration = configuration else { preconditionFailure() }
            configuration.includesBarriers = includeBarriers
            configuration.includesContainers = includeContainers
            configuration.traversability?.barriers = chainExpressions(traceConditionalExpressions)
            parameters.traceConfiguration = configuration
            
            do {
                // Trace the utility network.
                let traceResults = try await utilityNetwork
                    .trace(using: parameters)
                let elementResult = traceResults.first(
                    where: { $0 is UtilityElementTraceResult }
                ) as! UtilityElementTraceResult?
                // Display the number of elements found by the trace.
                traceResultsCount = elementResult?.elements.count ?? .zero
            } catch {
                throw error
            }
        }
        
        /// Resets the trace barrier conditions.
        func reset() {
            // Reset the barrier condition to the initial value.
            configuration?.traversability?.barriers = initialExpression
            if let initialExpression = initialExpression {
                // Add back the initial expression.
                traceConditionalExpressions = [initialExpression]
                conditions = [string(for: initialExpression)]
            } else {
                traceConditionalExpressions.removeAll()
                conditions.removeAll()
            }
            statusText = ""
        }
        
        /// Chains the conditional expressions together with AND or OR operators.
        /// - Parameter expressions: An array of `UtilityTraceConditionalExpression`s.
        /// - Returns: The chained conditional expression.
        func chainExpressions(
            _ expressions: [UtilityTraceConditionalExpression]
        ) -> UtilityTraceConditionalExpression? {
            guard let firstExpression = expressions.first else { return nil }
            /// The operator to chain conditions together, i.e. `AND` or `OR`.
            /// - Note: You may also combine expressions with
            /// `UtilityTraceAndCondition`. i.e. `UtilityTraceAndCondition.init`
            let chainingOperator = UtilityTraceOrCondition.init
            return expressions.dropFirst().reduce(firstExpression) { leftCondition, rightCondition in
                chainingOperator(leftCondition, rightCondition)
            }
        }
        
        /// Converts a `UtilityTraceConditionalExpression` into a readable string.
        /// - Parameter expression: A `UtilityTraceConditionalExpression`.
        /// - Returns: A string describing the expression.
        private func string(for expression: UtilityTraceConditionalExpression) -> String {
            switch expression {
            case let categoryComparison as UtilityCategoryComparison:
                return "`\(categoryComparison.category.name)` \(categoryComparison.operator.title)"
            case let attributeComparison as UtilityNetworkAttributeComparison:
                let attributeName = attributeComparison.networkAttribute.name
                let comparisonOperator = attributeComparison.operator.title
                
                if let otherName = attributeComparison.otherNetworkAttribute?.name {
                    // Comparing with another network attribute.
                    return "`\(attributeName)` \(comparisonOperator) `\(otherName)`"
                } else if let value = attributeComparison.value {
                    // Comparing with a value domain value or user input.
                    let dataType = attributeComparison.networkAttribute.dataType
                    
                    if let domain = attributeComparison.networkAttribute.domain as? CodedValueDomain,
                       let codedValue = domain.codedValues.first(
                        where: { compareAttributeData(dataType: dataType, value1: $0.code!, value2: value) }
                       ) {
                        // Check if attribute domain is a coded value domain.
                        return "'\(attributeName)' \(comparisonOperator) '\(codedValue.name)'"
                    } else if let formattedValue = value as? Double {
                        // Comparing with user input of type `Double`.
                        return "`\(attributeName)` \(comparisonOperator) `\(formattedValue.formatted())`"
                    } else {
                        // Comparing with user input.
                        return "`\(attributeName)` \(comparisonOperator) `\(value)`"
                    }
                } else {
                    fatalError("Unknown attribute comparison expression")
                }
            case let andCondition as UtilityTraceAndCondition:
                return """
                    (\(string(for: andCondition.leftExpression))) AND
                    (\(string(for: andCondition.rightExpression)))
                    """
            case let orCondition as UtilityTraceOrCondition:
                return """
                    (\(string(for: orCondition.leftExpression))) OR
                    (\(string(for: orCondition.rightExpression)))
                    """
            default:
                fatalError("Unknown trace condition expression type")
            }
        }
        
        /// Compares two attribute values.
        /// - Parameters:
        ///   - dataType: A `UtilityNetworkAttributeDataType` enum that tells the type of 2 values.
        ///   - value1: The lhs value to compare.
        ///   - value2: The rhs value to compare.
        /// - Returns: A boolean indicating if the values are euqal both in type and in value.
        func compareAttributeData(dataType: UtilityNetworkAttribute.DataType, value1: Any, value2: Any) -> Bool {
            switch dataType {
            case .boolean:
                return value1 as? Bool == value2 as? Bool
            case .double:
                return value1 as? Double == value2 as? Double
            case .float:
                return value1 as? Float == value2 as? Float
            case .integer:
                if let value1 = value1 as? Int16,
                   let value2 = value2 as? Int {
                    return value1 == value2
                } else if let value1 = value1 as? Int16,
                          let value2 = value2 as? Int16 {
                    return value1 == value2
                } else {
                    return false
                }
            @unknown default:
                fatalError("Unexpected utility network attribute data type.")
            }
        }
        
        /// Adds a conditional expression.
        func addConditionalExpression(
            attribute: UtilityNetworkAttribute,
            comparison: UtilityNetworkAttributeComparison.Operator,
            value: Any
        ) throws {
            let convertedValue: Any
            
            if let codedValue = value as? CodedValue, attribute.domain is CodedValueDomain {
                convertedValue = convertToDataType(value: codedValue.code!, dataType: attribute.dataType)
            } else {
                convertedValue = convertToDataType(value: value, dataType: attribute.dataType)
            }
            
            if let expression = UtilityNetworkAttributeComparison(
                networkAttribute: attribute,
                operator: comparison,
                value: convertedValue
            ) {
                traceConditionalExpressions.append(expression)
                conditions.append(string(for: expression))
            } else {
                throw InitExpressionError()
            }
        }
        
        /// Deletes a conditional expression.
        func deleteConditionalExpression(atOffsets indexSet: IndexSet) {
            guard let index = indexSet.first else { return }
            let condition = conditions[index]
            conditions = conditions.filter { $0 != condition }
            traceConditionalExpressions.remove(atOffsets: indexSet)
        }
        
        /// Converts the values to matching data types.
        /// - Note: The input value can either be an `CodedValue` populated from the left hand side
        ///         attribute's domain, or a numeric value entered by the user.
        /// - Parameters:
        ///   - value: The right hand side value used in the conditional expression.
        ///   - dataType: An `UtilityNetworkAttribute.DataType` enum case.
        /// - Returns: Converted value.
        func convertToDataType(value: Any, dataType: UtilityNetworkAttribute.DataType) -> Any {
            switch dataType {
            case .integer:
                if let value = value as? Int16 {
                    return value
                } else if let value = value as? Int64 {
                    return value
                } else if let value = value as? Double {
                    return Int64(value)
                } else {
                    return value as! Int64
                }
            case .float:
                return value as! Float
            case .double:
                return value as! Double
            case .boolean:
                return value as! Bool
            @unknown default:
                fatalError("Unexpected utility network attribute data type.")
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

extension AnalyzeNetworkWithSubnetworkTraceView.Model {
    /// An error returned when data required to setup the sample cannot be found.
    struct SetupError: LocalizedError {
        var errorDescription: String? {
            .init(
                localized: "Cannot find data required to setup the sample.",
                comment: "Description of error thrown when the setup for the sample fails."
            )
        }
    }
    
    /// An error returned when the conditional expression cannot be initialized.
    struct InitExpressionError: LocalizedError {
        var errorDescription: String? {
            .init(
                localized: "Could not initialize conditional expression.",
                comment: "Description of error thrown when the conditional expression cannot be initialized."
            )
        }
    }
}

private extension URL {
    /// The URL to the feature service for running the isolation trace.
    static var featureServiceURL: URL {
        URL(string: "https://sampleserver7.arcgisonline.com/server/rest/services/UtilityNetwork/NapervilleElectric/FeatureServer")!
    }
}

private extension UtilityCategoryComparison.Operator {
    /// An extension of `UtilityCategoryComparison.Operator` that returns a human readable description.
    /// - Note: You may also create a `UtilityCategoryComparison` with
    /// `UtilityNetworkDefinition.categories` and `UtilityCategoryComparison.Operator`.
    var title: String {
        switch self {
        case .exists: return "Exists"
        case .doesNotExist: return "DoesNotExist"
        @unknown default: return "Unknown"
        }
    }
}

extension UtilityNetworkAttributeComparison.Operator {
    /// A human-readable label for each utility attribute comparison operator.
    var title: String {
        switch self {
        case .equal: return "Equal"
        case .notEqual: return "Not Equal"
        case .greaterThan: return "Greater Than"
        case .greaterThanEqual: return "Greater Than Equal"
        case .lessThan: return "Less Than"
        case .lessThanEqual: return "Less Than Equal"
        case .includesTheValues: return "Includes The Values"
        case .doesNotIncludeTheValues: return "Does Not Include The Values"
        case .includesAny: return "Includes Any"
        case .doesNotIncludeAny: return "Does Not Include Any"
        @unknown default: return "Unknown"
        }
    }
}
