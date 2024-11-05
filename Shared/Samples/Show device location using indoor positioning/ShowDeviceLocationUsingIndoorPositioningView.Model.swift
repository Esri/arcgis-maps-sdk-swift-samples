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
import Combine
import Foundation

extension ShowDeviceLocationUsingIndoorPositioningView {
    @MainActor
    class Model: ObservableObject {
        /// An IPS-aware and floor-aware web map for all three floors of 
        /// Esri Building L in Redlands.
        let map = Map(item: PortalItem(portal: .arcGISOnline(connection: .anonymous), id: .indoorsMap))
        
        /// A Boolean value indicating whether the indoors data is loaded.
        @Published private(set) var isLoading = false
        
        /// The current floor level.
        @Published private(set) var currentFloor: Int?
        
        /// The horizontal accuracy of the location (in meters).
        @Published private(set) var horizontalAccuracy: Double?
        
        /// The source of the location data.
        @Published private(set) var positionSource: String?
        
        /// The number of BLE sensors or GNSS satellites used for providing location.
        @Published private(set) var signalSourceCount: Int?
        
        /// The map's location display.
        let locationDisplay: LocationDisplay = {
            // By default, uses the device's system location.
            let locationDisplay = LocationDisplay(dataSource: SystemLocationDataSource())
            locationDisplay.autoPanMode = .compassNavigation
            return locationDisplay
        }()
        
        /// Loads the indoors data.
        func loadIndoorsData() async throws {
            isLoading = true
            defer { isLoading = false }
            try await map.load()
            // For manually creating the indoors location data source only.
            await map.tables.load()
            if let floorManager = map.floorManager {
                // Load the floor manager if the map is floor-aware.
                // Most IPS-aware maps are also floor-aware.
                try await floorManager.load()
                // Only displays the ground floor when initialized.
                for level in floorManager.levels {
                    level.isVisible = level.verticalOrder == .zero
                }
            }
            try await setUpIndoorsLocationDataSource()
        }
        
        /// Sets the indoors location data source on the location display
        /// depending on whether the map contains an indoor positioning definition.
        private func setUpIndoorsLocationDataSource() async throws {
            let dataSource: IndoorsLocationDataSource
            if let indoorPositioningDefinition = map.indoorPositioningDefinition {
                // If an indoor positioning definition exists in the map, uses it
                // to set the IndoorsLocationDataSource. This is the recommended approach.
                try await indoorPositioningDefinition.load()
                dataSource = IndoorsLocationDataSource(definition: indoorPositioningDefinition)
            } else if let positioningTable = map.tables.first(where: { $0.tableName == "ips_positioning" }) as? ServiceFeatureTable {
                // Otherwise, creates the IndoorsLocationDataSource using
                // IPS positioning table information. This is useful for
                // manually creating an indoors location data source.
                dataSource = try await makeIndoorsLocationDataSourceFromTables(map: map, positioningTable: positioningTable)
            } else {
                throw SetupError()
            }
            locationDisplay.dataSource = dataSource
            // Starts the location display.
            try await locationDisplay.dataSource.start()
        }
        
        /// Creates an indoor location data source from the maps tables
        /// when there is no indoors definition.
        /// - Parameters:
        ///   - map: The map which contains the data in accordance with
        ///   the ArcGIS Indoors Information Model.
        ///   - positioningTable: The “ips\_positioning” table from
        ///   an IPS-aware map.
        /// - Returns: Returns a configured `IndoorsLocationDataSource` created
        /// from the various tables.
        private func makeIndoorsLocationDataSourceFromTables(
            map: Map,
            positioningTable: ServiceFeatureTable
        ) async throws -> IndoorsLocationDataSource {
            let queryParameters = QueryParameters()
            queryParameters.maxFeatures = 1
            // Gets the specific version of data that is compatible to the schema.
            // When use your own map, make sure the query returns the correct data.
            queryParameters.whereClause = "OBJECTID=2"
            // Queries a feature in the positioning table to get the positioning ID.
            let queryResult = try await positioningTable.queryFeatures(using: queryParameters)
            let feature = queryResult.features().makeIterator().next()!
            // The ID that identifies a row in the positioning table.
            // It is possible to initialize ILDS without globalID,
            // in which case the first row of the positioning table
            // will be used.
            let positioningID = feature.attributes[positioningTable.globalIDField] as? UUID
            // Gets the pathways table (optional for creating the IndoorsLocationDataSource).
            // The network pathways for routing between locations on the same level.
            let pathwaysTable = (
                map.operationalLayers.first(where: { $0.name == "Pathways" }) as! FeatureLayer
            ).featureTable as! ArcGISFeatureTable
            // Gets the levels layer (optional for creating the IndoorsLocationDataSource).
            // The table that contains floor levels.
            let levelsTable = (
                map.operationalLayers.first(where: { $0.name == "Levels" }) as! FeatureLayer
            ).featureTable as! ArcGISFeatureTable
            // Initialize an IndoorsLocationDataSource with positioning, pathways,
            // levels tables, and positioning ID.
            return IndoorsLocationDataSource(
                positioningTable: positioningTable,
                pathwaysTable: pathwaysTable,
                levelsTable: levelsTable,
                positioningID: positioningID
            )
        }
        
        /// Updates the location when the location data source is triggered.
        func updateDisplayOnLocationChange() async {
            for await location in locationDisplay.dataSource.locations {
                // The floor level from the location.
                if let floor = location.additionalSourceProperties[.floor] as? Int,
                   let levelID = location.additionalSourceProperties[.floorLevelID] as? String {
                    currentFloor = floor
                    // Only displays the current floor.
                    if let floorManager = map.floorManager {
                        for level in floorManager.levels {
                            level.isVisible = FloorLevel.ID(levelID) == level.id
                        }
                    }
                }
                // The position source where the location data was sourced from:
                // GNSS (Satellites), BLE (Bluetooth Low Energy),
                // or AppleIPS (Apple's proprietary location system), etc.
                if let source = location.additionalSourceProperties[.positionSource] as? String {
                    positionSource = source
                    switch source {
                    case "GNSS":
                        signalSourceCount = location.additionalSourceProperties[.satelliteCount] as? Int
                    default:
                        // Bluetooth, Cellular, WiFi, etc.
                        signalSourceCount = location.additionalSourceProperties[.transmitterCount] as? Int
                    }
                }
                // The horizontal accuracy of the location in meters.
                horizontalAccuracy = location.horizontalAccuracy
            }
        }
    }
}

private extension PortalItem.ID {
    /// Esri campus Building L IPS data.
    static var indoorsMap: Self { Self("8fa941613b4b4b2b8a34ad4cdc3e4bba")! }
}

private extension ShowDeviceLocationUsingIndoorPositioningView.Model {
    /// An error returned when the indoors data required to setup the sample is malformatted.
    struct SetupError: LocalizedError {
        var errorDescription: String? {
            .init(
                localized: "Cannot initialize indoors location data source.",
                comment: "No indoor positioning definition or positioning table is found."
            )
        }
    }
}
