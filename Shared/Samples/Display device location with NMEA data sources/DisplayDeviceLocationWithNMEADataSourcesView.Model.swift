// Copyright 2022 Esri
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
import ExternalAccessory

extension DisplayDeviceLocationWithNMEADataSourcesView {
    /// The model used to store the geo model and other expensive objects used in this view.
    class Model: ObservableObject {
        /// A map with a navigation basemap.
        let map = Map(basemapStyle: .arcGISNavigation)
        
        /// The current autopan mode.
        var autoPanMode: LocationDisplay.AutoPanMode {
            get {
                locationDisplay.autoPanMode
            }
            set {
                locationDisplay.autoPanMode = newValue
            }
        }
        
        /// A Boolean value specifying if the "recenter" button should be disabled.
        @Published var isRecenterButtonDisabled = true
        
        /// A Boolean value specifying if the "reset" button should be disabled.
        @Published var isResetButtonDisabled = true
        
        /// A Boolean value specifying if the "source" button should be disabled.
        @Published var isSourceMenuDisabled = false
        
        /// A string containing GPS accuracy.
        @Published var accuracyStatus = "Accuracy info will be shown here."
        
        /// A string containing satellite information.
        @Published var satelliteStatus = "Satellites info will be shown here."
        
        /// The location display used in the map view.
        let locationDisplay: LocationDisplay = {
            let locationDisplay = LocationDisplay()
            locationDisplay.autoPanMode = .recenter
            return locationDisplay
        }()
        
        /// An NMEA location data source, to parse NMEA data.
        private var nmeaLocationDataSource: NMEALocationDataSource!
        
        /// A mock data source to read NMEA sentences from a local file, and generate
        /// mock NMEA data every fixed amount of time.
        private let mockNMEADataSource = SimulatedNMEAData(nmeaSourceFile: Bundle.main.url(forResource: "Redlands", withExtension: "nmea")!, speed: 1.5)
        
        /// A format style for the accuracy distance string.
        private let formatStyle: Measurement<UnitLength>.FormatStyle = {
            Measurement<UnitLength>.FormatStyle.measurement(
                width: .abbreviated,
                usage: .general,
                numberFormatStyle: .number.precision(.fractionLength(1))
            )
        }()
        
        private let listFormatStyle: ListFormatStyle<StringStyle, Array> = {
            .list(type: .and, width: .narrow)
        }()
        
        /// The protocols used in this sample to get NMEA sentences.
        /// They are also specified in the `Info.plist` to allow the app to
        /// communicate with external accessory hardware.
        private let supportedProtocolStrings = [
            "com.bad-elf.gps",
            "com.eos-gnss.positioningsource",
            "com.geneq.sxbluegpssource"
        ]
        
        /// The observation tasks created during starting the data source.
        private var observationTasks = [Task<Void, Never>]()
        
        deinit {
            cancelObservationTasks()
        }
        
        /// Cancel and remove tasks from list of observation tasks.
        private func cancelObservationTasks() {
            observationTasks.forEach { task in
                task.cancel()
            }
            observationTasks.removeAll()
        }
        
        /// Get the first connected and supported Bluetooth accessory with its
        /// protocol string.
        /// - Returns: A tuple of the accessory and its protocol,
        /// or `nil` if no supported accessory exists.
        func firstSupportedAccessoryWithProtocol() -> (EAAccessory, String)? {
            for accessory in EAAccessoryManager.shared().connectedAccessories {
                // The protocol string to establish the EASession.
                guard let protocolString = accessory.protocolStrings.first(where: { supportedProtocolStrings.contains($0) }) else {
                    // Skip the accessories with protocol not for NMEA data transfer.
                    continue
                }
                // Only return the first connected and supported accessory.
                return (accessory, protocolString)
            }
            return nil
        }
        
        /// The Bluetooth accessory picker connected to a supported accessory.
        func accessoryDidConnect(connectedAccessory: EAAccessory, protocolString: String) {
            if let dataSource = NMEALocationDataSource(accessory: connectedAccessory, protocol: protocolString) {
                nmeaLocationDataSource = dataSource
                start()
            }
        }
        
        /// Reset the sample, stops the data source, cancels tasks, and resets button states and status strings.
        func reset() {
            // Reset buttons states.
            isResetButtonDisabled = true
            isSourceMenuDisabled = false
            
            // Reset the status text.
            accuracyStatus = "Accuracy info will be shown here."
            satelliteStatus = "Satellites info will be shown here."
            
            // Reset NMEA location data source.
            nmeaLocationDataSource = nil
            autoPanMode = .off

            Task {
                // Stop the location display, which in turn stop the data source.
                await locationDisplay.dataSource.stop()
            }
            
            // Cancel the autoPan, location, and satellite observation tasks.
            cancelObservationTasks()
            
            // Pause the mock data generation.
            mockNMEADataSource.stop()
        }

        /// Starts the location data source and awaits location and satellite updates.
        /// - Parameter usingMockedData: Indicates that the location datasource should use mocked data.
        func start(usingMockedData: Bool = false) {
            if usingMockedData {
                nmeaLocationDataSource = NMEALocationDataSource(receiverSpatialReference: .wgs84)
            }
            
            // Set NMEA location data source for location display.
            locationDisplay.dataSource = nmeaLocationDataSource
            // Set buttons states.
            isSourceMenuDisabled = true
            isResetButtonDisabled = false
            
            // Start the data source and location display.
            if usingMockedData {
                mockNMEADataSource.start(with: nmeaLocationDataSource)
            }
            
            // Set the autopan mode to `.recenter`
            autoPanMode = .recenter

            Task {
                // Start the data source
                try await locationDisplay.dataSource.start()
            }
            
            // Kick off tasks to monitor autoPan, locations, and satellites.
            observationTasks.append(
                contentsOf: [
                    observeAutoPanTask,
                    observeLocationsTask,
                    observeSatellitesTask
                ]
            )
        }
        
        /// A detached task observing location display autoPan changes.
        var observeAutoPanTask: Task<Void, Never> {
            Task.detached { [unowned self] in
                for await mode in locationDisplay.$autoPanMode {
                    await MainActor.run {
                        isRecenterButtonDisabled = nmeaLocationDataSource == nil || mode == .recenter
                    }
                }
            }
        }
        
        /// A detached task observing location data source location changes.
        var observeLocationsTask: Task<Void, Never> {
            Task.detached { [unowned self] in
                for await location in nmeaLocationDataSource.locations {
                    guard let nmeaLocation = location as? NMEALocation else { return }
                    let horizontalAccuracy = Measurement(
                        value: nmeaLocation.horizontalAccuracy,
                        unit: UnitLength.meters
                    )
                    
                    let verticalAccuracy = Measurement(
                        value: nmeaLocation.verticalAccuracy,
                        unit: UnitLength.meters
                    )
                    
                    let accuracyText = String(
                        format: "Accuracy - Horizontal: %@; Vertical: %@",
                        horizontalAccuracy.formatted(formatStyle),
                        verticalAccuracy.formatted(formatStyle)
                    )
                    
                    await MainActor.run {
                        accuracyStatus = accuracyText
                    }
                }
            }
        }
        
        /// A detached task observing NMEA location data source satellite changes.
        var observeSatellitesTask: Task<Void, Never> {
            Task.detached { [unowned self] in
                for await satellites in nmeaLocationDataSource.satellites {
                    guard nmeaLocationDataSource.status == .started else { return }
                    
                    // Update the satellites info status text.
                    let satelliteSystems = satellites.filter {
                        $0.system != nil
                    }
                    
                    let satelliteLabels = Set(satelliteSystems
                        .map(\.system!.label))
                        .sorted()
                        .formatted(listFormatStyle)
                    
                    let satellliteIDs = satelliteSystems
                        .map { String($0.id) }
                        .formatted(listFormatStyle)
                    
                    await MainActor.run {
                        satelliteStatus = String(
                            format: """
                                    %d satellites in view
                                    System(s): %@
                                    IDs: %@
                                    """,
                            satellites.count,
                            satelliteLabels,
                            satellliteIDs
                        )
                    }
                }
            }
        }
    }
}

private extension NMEAGNSSSystem {
    var label: String {
        switch self {
        case .gps:
            return "The Global Positioning System"
        case .glonass:
            return "The Russian Global Navigation Satellite System"
        case .galileo:
            return "The European Union Global Navigation Satellite System"
        case .bds:
            return "The BeiDou Navigation Satellite System"
        case .qzss:
            return "The Quasi-Zenith Satellite System"
        case .navIC:
            return "The Navigation Indian Constellation"
        default:
            return "Unknown GNSS type"
        }
    }
}
