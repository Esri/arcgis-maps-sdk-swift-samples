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
        
        @Published private(set) var currentFloor: Int = -1
        
        @Published private(set) var sensorCount: Int!
        
        @Published private(set) var satelliteCount: Int!
        
        @Published private(set) var horizontalAccuracy: Double!
        
        /// The map's location display.
        @Published private(set) var locationDisplay = LocationDisplay()
        
        @Published private(set) var source: String = ""
        
        func setIndoorDatasource(map: Map) async throws {
            locationDisplay.autoPanMode = .compassNavigation
            try await map.indoorPositioningDefinition?.load()
            try await map.floorManager?.load()
            indoorsLocationDataSource = IndoorsLocationDataSource(definition: map.indoorPositioningDefinition!)
            locationDisplay.dataSource = indoorsLocationDataSource!
            try await startLocationDisplay()
            try await updateLocation(map: map)
        }
        
        private func updateLocation(map: Map) async throws {
            for try await location in locationDisplay.dataSource.locations {
                if let floorLevel = location.additionalSourceProperties[.floor] as? Int {
                    if (floorLevel + 1) != currentFloor {
                        currentFloor = floorLevel + 1
                        try await displayFeatures(map: map, onFloor: currentFloor)
                    }
                }
                source = location.additionalSourceProperties[.positionSource] as? String ?? "NA"
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
        private func startLocationDisplay() async throws {
            // Request location permission if it has not yet been determined.
            let locationManager = CLLocationManager()
            if locationManager.authorizationStatus == .notDetermined {
                locationManager.requestWhenInUseAuthorization()
            }
            // Start the location display to zoom to the user's current location.
            try await locationDisplay.dataSource.start()
        }
        
        /// Display features on a certain floor level using definition expression.
        /// - Parameter floor: The floor level of the features to be displayed.
        private func displayFeatures(map: Map, onFloor floor: Int) async throws {
            map.floorManager!.levels.forEach {
                if currentFloor == $0.levelNumber {
                    $0.isVisible = true
                } else {
                    $0.isVisible = false
                }
            }
            for layer in map.operationalLayers {
                if layer.name == "Details" || layer.name == "Levels" {
                    if let featureLayer = layer as? FeatureLayer {
                        featureLayer.definitionExpression = "VERTICAL_ORDER = \(floor)"
                    }
                }
            }
        }
    }
}
