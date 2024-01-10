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

extension SearchForWebMapView {
    /// The view model for the sample.
    class Model: ObservableObject {
        /// A portal to ArcGIS Online to get the portal items from.
        private let portal = Portal.arcGISOnline(connection: .anonymous)
        
        /// The query parameters for the next set of results based on the last results.
        private var nextQueryParameters: PortalQueryParameters?
        
        /// The task used to find portal times thorough the portal.
        private var task: Task<Void, Error>?
        
        /// The portal items resulting from a search.
        @Published private(set) var portalItems: [PortalItem] = []
        
        /// A Boolean value indicating whether new results are being loaded.
        @Published private(set) var isLoadingResults = false
        
        deinit {
            task?.cancel()
        }
        
        /// Finds the portal items that match the given query.
        /// - Parameter query: The text query used to find the portal items.
        func findItems(for query: String) throws {
            // Cancel the current search operation if there is one.
            task?.cancel()
            isLoadingResults = false
            
            if query.isEmpty {
                portalItems.removeAll()
                return
            }
            
            // Find the new results.
            isLoadingResults = true
            task = Task {
                let parameters = try queryParameters(for: query)
                let results = try await findItems(using: parameters)
                
                await MainActor.run {
                    portalItems = results
                    isLoadingResults = false
                }
            }
        }

        /// Finds the portal items that match the next query parameters from the previous search.
        func findNextItems() throws {
            guard let nextQueryParameters else { return }
            // Cancel the current search operation if there is one.
            task?.cancel()
            isLoadingResults = false

            // Find the next results.
            isLoadingResults = true
            task = Task {
                let nextResults = try await findItems(using: nextQueryParameters)
                
                await MainActor.run {
                    portalItems.append(contentsOf: nextResults)
                    isLoadingResults = false
                }
            }
        }
        
        /// Finds the portal items that match the given query parameters.
        /// - Parameter queryParameters: The portal query parameters to find the portal items.
        /// - Returns: The portal items that were found.
        private func findItems(using queryParameters: PortalQueryParameters) async throws -> [PortalItem] {
            // Get the results from the portal using the parameters.
            let resultsSet = try await portal.findItems(queryParameters: queryParameters)
            nextQueryParameters = resultsSet.nextQueryParameters
            return resultsSet.results
        }
        
        /// The portal query parameters for a given query.
        /// - Parameter query: The text query used to create the parameters.
        /// - Returns: A new `PortalQueryParameters` object.
        private func queryParameters(for query: String) throws -> PortalQueryParameters {
            // Create a date string for a date range to search within.
            // Note: Web maps authored prior to July 2nd, 2014 are not supported.
            let startDate = try Date(
                "July 2, 2014",
                strategy: Date.FormatStyle().day().month().year().parseStrategy
            )
            let dateRange = startDate.millisecondsSince1970...Date.now.millisecondsSince1970
            let dateString = "uploaded:[\(dateRange.lowerBound) TO \(dateRange.upperBound)]"
            
            // Create a string to filter for web maps.
            let typeString = "type:\"Web Map\""
            
            // Create the portal query parameters with the strings.
            return PortalQueryParameters(query: "\(query) AND \(typeString) AND \(dateString)")
        }
    }
}

private extension Date {
    /// The milliseconds between the date value and 00:00:00 UTC on 1 January 1970.
    var millisecondsSince1970: Int64 {
        Int64(timeIntervalSince1970 * 1_000)
    }
}
