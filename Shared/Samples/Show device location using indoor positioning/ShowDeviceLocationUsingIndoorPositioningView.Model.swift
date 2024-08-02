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
        /// An IPS-aware web map for all three floors of Esri Building L in Redlands.
        let map = Map(url: .indoorsMap)!
        
        /// The value of the current floor with -1 being used to represent floor that has not been set.
        private var currentFloor: Int?
        
        /// The number of BLE sensors which are being used for indoor location.
        private var sensorCount: Int?
        
        /// Counts the number of satellites which being used for the GPS location.
        private var satelliteCount: Int?
        
        /// The value of the horizontal accuracy of the location (in meters).
        private var horizontalAccuracy: Double?
        
        /// An indoors location data source based on sensor data, including but not
        /// limited to radio, GPS, motion sensors.
        private var indoorsLocationDataSource: IndoorsLocationDataSource?
        
        /// The map's location display.
        let locationDisplay = LocationDisplay(dataSource: SystemLocationDataSource())
        
        /// This is the published value of the data that is displayed.
        @Published private(set) var labelTextLeading: String = ""
        
        /// This is the published value of the data that is displayed.
        @Published private(set) var labelTextTrailing: String = ""
        
        /// Represents loading state of indoors data, blocks interaction until loaded.
        @Published private(set) var isLoading = false
        
        /// Kicks off the logic loading the data for the indoors map and indoors location.
        func loadIndoorData() async throws {
            isLoading = true
            defer { isLoading = false }
            try await map.load()
            try await setIndoorDatasource()
        }
        
        /// Stops the location data source.
        func stopLocationDataSource() {
            Task {
                await locationDisplay.dataSource.stop()
            }
        }
        
        /// Sets the indoor datasource on the location display depending on
        /// whether the map contains an IndoorDefinition.
        private func setIndoorDatasource() async throws {
            try await map.floorManager?.load()
            // If an indoor definition exists in the map, it gets loaded and sets the IndoorsDataSource to pull information
            // from the definition, otherwise the IndoorsDataSource attempts to create itself using IPS table information.
            if let indoorPositioningDefinition = map.indoorPositioningDefinition {
                try await indoorPositioningDefinition.load()
                indoorsLocationDataSource = IndoorsLocationDataSource(definition: indoorPositioningDefinition)
            } else {
                indoorsLocationDataSource = try await createIndoorLocationDataSourceFromTables(map: map)
            }
            // This ensures that the details of the inside of the building, like room layouts are displayed.
            for featLayer in map.operationalLayers {
                if featLayer.name == "Transitions" || featLayer.name == "Details" {
                    featLayer.isVisible = true
                }
            }
            // The indoorsLocationDataSource should always be there. Since the createIndoorLocationDataSourceFromTables returns
            // an optional value it cannot be guaranteed. Best option if you get to this point without a datasource
            // is to return (ideally an error would have been thrown before this point and the flow broken.)
            guard let dataSource = indoorsLocationDataSource else { return }
            locationDisplay.dataSource = dataSource
            locationDisplay.autoPanMode = .compassNavigation
            // Start the location display to zoom to the user's current location.
            try await locationDisplay.dataSource.start()
        }
        
        /// Creates an indoor location datasource from the maps tables if there is no indoors definition.
        /// - Parameter map: The map which contains the tables from which the data source is constructed.
        /// - Returns: Returns a configured IndoorsLocationDataSource created from the IPS position table.
        private func createIndoorLocationDataSourceFromTables(map: Map) async throws -> IndoorsLocationDataSource? {
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
        func updateDisplayOnLocationChange() async throws {
            for await location in locationDisplay.dataSource.locations {
                // Since this listens for new location changes, it is important
                // to ensure any blocking UI is dismissed once location updates begins.
                // Floors in location are zero indexed however floorManager levels begin at one. Since
                // it is necessary to display the same information to the user as the floor manager levelNumber
                // one is added to the floor level value.
                if let floorLevel = location.additionalSourceProperties[.floor] as? Int,
                   (floorLevel + 1) != currentFloor {
                    // Sets the currentFloor to the new floor level and adds one, since location uses
                    // zero based flooring system.
                    currentFloor = floorLevel + 1
                    // The floor manager is used to filter so that only the data from the current floor is
                    // displayed to the user.
                    if let floorManager = map.floorManager {
                        floorManager.levels.forEach {
                            $0.isVisible = currentFloor == $0.levelNumber
                        }
                    }
                }
                // This indicates whether the location data was sourced from GNSS (Satellites), BLE (Bluetooth Low Energy)
                // or AppleIPS (Apple's proprietary location system.
                let source = location.additionalSourceProperties[.positionSource] as? String ?? ""
                switch source {
                case "GNSS":
                    satelliteCount = location.additionalSourceProperties[.satelliteCount] as? Int ?? 0
                default:
                    sensorCount = location.additionalSourceProperties[.transmitterCount] as? Int ?? 0
                }
                horizontalAccuracy = location.horizontalAccuracy
                // Updates every time the location changes.
                getStatusLabelText(source: source)
            }
        }
        
        /// Updates the labels on the view with the current state of the indoors data source.
        private func getStatusLabelText(source: String) {
            labelTextLeading = ""
            labelTextTrailing = ""
            if let currentFloor {
                labelTextLeading += "Current floor: \(currentFloor)\n"
                if let horizontalAccuracy {
                    var horizontalAccuracyMeasurement = Measurement<UnitLength>(value: horizontalAccuracy, unit: .meters)
                    labelTextLeading += "Accuracy: \(horizontalAccuracyMeasurement.formatted(.distance))"
                }
                if let sensorCount {
                    labelTextTrailing += "Number of sensors: \(sensorCount)\n"
                } else if let satelliteCount, source == "GNSS" {
                    labelTextTrailing += "Number of satellites: \(satelliteCount)\n"
                }
                labelTextTrailing += "Data source: \(source)"
            } else {
                labelTextLeading = "No floor data."
            }
        }
    }
}

private extension URL {
    static var indoorsMap: URL {
        URL(string: "https://www.arcgis.com/home/item.html?id=8fa941613b4b4b2b8a34ad4cdc3e4bba")!
    }
}

private extension FormatStyle where Self == Measurement<UnitLength>.FormatStyle {
    /// The format style for the distances.
    static var distance: Self {
        .measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(2)))
    }
}
