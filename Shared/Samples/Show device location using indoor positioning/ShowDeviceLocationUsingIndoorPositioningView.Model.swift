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
import CoreLocation
import SwiftUI

extension ShowDeviceLocationUsingIndoorPositioningView {
    @MainActor
    class Model: ObservableObject {
        /// A indoors location data source based on sensor data, including but not
        /// limited to radio, GPS, motion sensors.
        @Published private(set) var indoorsLocationDataSource: IndoorsLocationDataSource?
        
        /// The value of the current floor with -1 being used to represent floor that has not been set.
        @Published private(set) var currentFloor: Int = -1
        
        /// The number of BLE sensors which are being used for indoor location.
        @Published private(set) var sensorCount: Int!
        
        /// Counts the number of satellites which being used for the GPS location.
        @Published private(set) var satelliteCount: Int!
        
        /// The value of the horizontal accuracy of the location (in meters)
        @Published private(set) var horizontalAccuracy: Double!
        
        /// The map's location display.
        @Published private(set) var locationDisplay = LocationDisplay()
        
        ///  This value tracks whether the source is GPS or BLE
        @Published private(set) var source: String = ""
        
        /// A function that attempts to load an indoor definition attached to the map and returns a boolean value based whether it is loaded.
        /// - Parameter map: The map that contains the IndoorDefinition
        /// - Returns: A boolean value for whether the IndoorDefinition is loaded.
        func loadAndCheckForIndoorDefinition(map: Map) async throws -> Bool {
            try await map.indoorPositioningDefinition?.load()
            if map.indoorPositioningDefinition?.loadStatus == .loaded {
                return true
            }
            return false
        }
        
        /// Sets the indoor datasource on the location display depending on whether the map contains an IndoorDefinition.
        /// - Parameter map: The map which is checked for an indoor definition.
        func setIndoorDatasource(map: Map) async throws {
            locationDisplay.autoPanMode = .compassNavigation
            try await map.floorManager?.load()
            if try await loadAndCheckForIndoorDefinition(map: map),
               let indoorPositioningDefinition = map.indoorPositioningDefinition {
                indoorsLocationDataSource = IndoorsLocationDataSource(definition: indoorPositioningDefinition)
            } else {
                indoorsLocationDataSource = try await createIndoorLocationDataSource(map: map)
            }
            locationDisplay.dataSource = indoorsLocationDataSource!
        }
        
        /// Creates an indoor location datasource from the maps tables if there is no indoors definition.
        /// - Parameter map: The map which contains the tables from which the data source is constructed.
        /// - Returns: Returns a configured IndoorsLocationDataSource created from the IPS position table.
        private func createIndoorLocationDataSource(map: Map) async throws -> IndoorsLocationDataSource? {
            // Gets the positioning table from the map.
            guard let positioningTable = map.tables.first(where: { $0.displayName == "IPS_Positioning" }) else { return nil }
            // Creates and configures the query parameters.
            let queryParameters = QueryParameters()
            queryParameters.maxFeatures = 1
            queryParameters.whereClause = "1 = 1"
            // Queries positioning table to get the positioning ID.
            let queryResult = try await positioningTable.queryFeatures(using: queryParameters)
            guard let feature = queryResult.features().makeIterator().next() else { return nil }
            let serviceFeatureTable = positioningTable as! ServiceFeatureTable
            let positioningID = feature.attributes[serviceFeatureTable.globalIDField] as? UUID
            
            // Gets the pathways layer (optional for creating the IndoorsLocationDataSource).
            let pathwaysLayer = map.operationalLayers.first(where: { $0.name == "Pathways" }) as! FeatureLayer
            // Gets the levels layer (optional for creating the IndoorsLocationDataSource).
            let levelsLayer = map.operationalLayers.first(where: { $0.name == "Levels" }) as! FeatureLayer
            
            // Setting up IndoorsLocationDataSource with positioning, pathways tables and positioning ID.
            // positioningTable - the "IPS_Positioning" feature table from an IPS-aware map.
            // pathwaysTable - An ArcGISFeatureTable that contains pathways as per the ArcGIS Indoors Information Model.
            // Setting this property enables path snapping of locations provided by the IndoorsLocationDataSource.
            // levelsTable - An ArcGISFeatureTable that contains floor levels in accordance with the ArcGIS Indoors Information Model.
            // Providing this table enables the retrieval of a location's floor level ID.
            // positioningID - an ID which identifies a specific row in the positioningTable that should be used for setting up IPS.
            return IndoorsLocationDataSource(
                positioningTable: positioningTable,
                pathwaysTable: pathwaysLayer.featureTable as? ArcGISFeatureTable,
                levelsTable: levelsLayer.featureTable as? ArcGISFeatureTable,
                positioningID: positioningID
            )
        }
        
        /// The method that updates the location when the indoors location datasource is triggered.
        /// - Parameter floorManager: The floor manager that filters what is displayed on the map by floor.
        func updateLocation(floorManager: FloorManager) async throws {
            for try await location in locationDisplay.dataSource.locations {
                if let floorLevel = location.additionalSourceProperties[.floor] as? Int {
                    if (floorLevel + 1) != currentFloor {
                        currentFloor = floorLevel + 1
                        try await displayFeatures(floorManager: floorManager, onFloor: currentFloor)
                    }
                }
                source = location.additionalSourceProperties[.positionSource] as? String ?? "N/A"
                switch source {
                case "GNSS":
                    satelliteCount = location.additionalSourceProperties[.satelliteCount] as? Int ?? 0
                default:
                    sensorCount = location.additionalSourceProperties[.transmitterCount] as? Int ?? 0
                }
                horizontalAccuracy = location.horizontalAccuracy
            }
        }
        
        /// Starts the location display to show user's location on the map.
        func startLocationDisplay() async throws {
            // Request location permission if it has not yet been determined.
            let locationManager = CLLocationManager()
            if locationManager.authorizationStatus == .notDetermined {
                locationManager.requestWhenInUseAuthorization()
            }
            // Start the location display to zoom to the user's current location.
            try await locationDisplay.dataSource.start()
        }
        
        /// Display features on a certain floor level using definition expression.
        /// - Parameters:
        ///   - floorManager: A floor manager for filtering what is displayed on the map.
        ///   - floor:  The floor level of the features to be displayed.
        private func displayFeatures(floorManager: FloorManager, onFloor floor: Int) async throws {
            floorManager.levels.forEach {
                if currentFloor == $0.levelNumber {
                    $0.isVisible = true
                } else {
                    $0.isVisible = false
                }
            }
        }
    }
}
