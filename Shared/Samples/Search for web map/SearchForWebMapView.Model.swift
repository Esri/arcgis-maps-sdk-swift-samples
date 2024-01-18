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
    @MainActor
    class Model: ObservableObject {
        /// A portal to ArcGIS Online to get the portal items from.
        private let portal = Portal.arcGISOnline(connection: .anonymous)
        
        /// The query parameters for the next set of results based on the last results.
        private var nextQueryParameters: PortalQueryParameters?
        
        /// The text query from the last search.
        private var lastQuery = ""
        
        /// The portal items resulting from a search.
        @Published private(set) var portalItems: [PortalItem] = []
        
        /// Finds the portal items that match the given query.
        /// - Parameter query: The text query used to find the portal items.
        func findItems(for query: String) async throws {
            // Ensure that a new search is necessary.
            guard query != lastQuery else { return }
            
            if query.isEmpty {
                portalItems.removeAll()
                return
            }
            
            // Find the new results using parameters made with the query.
            let parameters = queryParameters(for: query)
            let results = try await portalItems(using: parameters)
            portalItems = results
            lastQuery = query
        }
        
        /// Finds the next portal item based on the last results.
        func findNextItems() async throws {
            guard let nextQueryParameters else { return }
            
            // Find the next results using the next query parameters from the last search.
            let nextResults = try await portalItems(using: nextQueryParameters)
            portalItems.append(contentsOf: nextResults)
        }
        
        /// The portal items from the portal that match the given query parameters.
        /// - Parameter queryParameters: The portal query parameters to find the portal items.
        /// - Returns: The portal items that were found.
        private func portalItems(using queryParameters: PortalQueryParameters) async throws -> [PortalItem] {
            // Get the results from the portal using the parameters.
            let resultsSet = try await portal.findItems(queryParameters: queryParameters)
            nextQueryParameters = resultsSet.nextQueryParameters
            return resultsSet.results
        }
        
        /// The portal query parameters for a given query.
        /// - Parameter query: The text query used to create the parameters.
        /// - Returns: A new `PortalQueryParameters` object.
        private func queryParameters(for query: String) -> PortalQueryParameters {
            // Create a date string for a date range to search within.
            // Note: Web maps authored prior to July 2nd, 2014 are not supported.
            let startDate = Date.webMapSupportedDate
            
            // Convert the dates to UNIX time to be able to use with the ArcGIS REST API.
            let dateRange = startDate.unixTime...Date.now.unixTime
            let dateString = "uploaded:[\(dateRange.lowerBound) TO \(dateRange.upperBound)]"
            
            // Create a string to filter for web maps.
            let typeString = #"type:"Web Map""#
            
            // Create the portal query parameters with the strings.
            let fullQuery = [query, typeString, dateString].joined(separator: " AND ")
            return PortalQueryParameters(query: fullQuery)
        }
    }
}

private extension Date {
    /// The date after which web maps are supported, July 2, 2014.
    static var webMapSupportedDate: Date {
        // swiftlint:disable:next force_try
        try! Date(
            "July 2, 2014",
            strategy: Date.FormatStyle().day().month().year().parseStrategy
        )
    }
    
    /// The milliseconds between the date value and 00:00:00 UTC on 1 January 1970.
    var unixTime: Int64 {
        Int64(timeIntervalSince1970 * 1_000)
    }
}
