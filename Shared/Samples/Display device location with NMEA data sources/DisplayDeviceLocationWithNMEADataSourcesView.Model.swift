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
    /// The model used to store the geo model and other expensive objects
    /// used in this view.
    @MainActor
    class Model: ObservableObject {
        /// A map with imagery basemap.
        let map = Map(basemapStyle: .arcGISNavigation)
        
        /// The current autopan mode.
        var autoPanMode: LocationDisplay.AutoPanMode = .recenter {
            didSet {
                locationDisplay.autoPanMode = autoPanMode
                isRecenterButtonDisabled = nmeaLocationDataSource == nil || autoPanMode == .recenter
            }
        }
        
        /// A Boolean value specifying if the "recenter" button should be disabled.
        @Published var isRecenterButtonDisabled = true
        
        /// A Boolean value specifying if the "reset" button should be disabled.
        @Published var isResetButtonDisabled = true
        
        /// A Boolean value specifying if the "source" button should be disabled.
        @Published var isSourceButtonDisabled = false
        
        /// A string containing GPS accuracy.
        @Published var accuracyStatus: String = "Accuracy info will be shown here."
        
        /// A string containing satellite information.
        @Published var satelliteStatus: String = "Satellites info will be shown here."
        
        /// The location display used in the map view.
        var locationDisplay = LocationDisplay()
        
        /// An NMEA location data source, to parse NMEA data.
        var nmeaLocationDataSource: NMEALocationDataSource!
        
        /// A mock data source to read NMEA sentences from a local file, and generate
        /// mock NMEA data every fixed amount of time.
        let mockNMEADataSource = SimulatedNMEADataSource(nmeaSourceFile: Bundle.main.url(forResource: "Redlands", withExtension: "nmea")!, speed: 1.5)
        
        /// A formatter for the accuracy distance string.
        let distanceFormatter: MeasurementFormatter = {
            let formatter = MeasurementFormatter()
            formatter.unitOptions = .naturalScale
            formatter.numberFormatter.minimumFractionDigits = 1
            formatter.numberFormatter.maximumFractionDigits = 1
            return formatter
        }()
        
        /// The protocols used in this sample to get NMEA sentences.
        /// They are also specified in the `Info.plist` to allow the app to
        /// communicate with external accessory hardware.
        let supportedProtocolStrings = [
            "com.bad-elf.gps",
            "com.eos-gnss.positioningsource",
            "com.geneq.sxbluegpssource"
        ]
        
        init() {
            Task {
                // Watch for changes in the location display's autopan mode.
                for await mode in locationDisplay.$autoPanMode {
                    if autoPanMode != mode {
                        autoPanMode = mode
                    }
                }
            }
        }
        
        /// Reset the sample, stopping the data source, resetting button states and status strings.
        func reset() {
            // Reset buttons states.
            isResetButtonDisabled = true
            isSourceButtonDisabled = false
            // Reset the status text.
            accuracyStatus = "Accuracy info will be shown here."
            satelliteStatus = "Satellites info will be shown here."
            
            Task {
                // Stop the location display, which in turn stop the data source.
                await nmeaLocationDataSource.stop()
                
                // Reset NMEA location data source.
                nmeaLocationDataSource = nil
                autoPanMode = .off
            }
            
            // Pause the mock data generation.
            mockNMEADataSource.stop()
        }
        
        /// Get the first connected and supported Bluetooth accessory with its
        /// protocol string.
        /// - Returns: A tuple of the accessory and its protocol,
        ///            or nil if no supported accessory exists.
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
        @discardableResult
        func accessoryDidConnect(connectedAccessory: EAAccessory, protocolString: String) -> Bool {
            if let dataSource = NMEALocationDataSource(accessory: connectedAccessory, protocol: protocolString) {
                nmeaLocationDataSource = dataSource
                start()
                return true
            }
            return false
        }
        
        /// Starts the location data source and awaits location and satellite updates.
        /// - Parameter usingMockedData: Indicates that the location datasource should use mocked data.
        func start(usingMockedData: Bool = false) {
            // Set NMEA location data source for location display.
            locationDisplay.dataSource = nmeaLocationDataSource
            // Set buttons states.
            isSourceButtonDisabled = true
            isResetButtonDisabled = false
            
            // Start the data source and location display.
            if usingMockedData {
                mockNMEADataSource.start(with: nmeaLocationDataSource)
            }
            
            Task {
                // Start the data source
                try? await nmeaLocationDataSource.start()
                
                // Set the autopan mode to `.recenter`
                autoPanMode = .recenter
                
                // Set up a TaskGroup to get asynchronous
                // location and satellite updates.
                await withTaskGroup(of: Void.self) { [weak self] taskGroup in
                    guard let self else { return }
                    taskGroup.addTask { await self.locations() }
                    taskGroup.addTask { await self.satellites() }
                }
            }
        }
        
        /// Starts iterating over location udpates and set the accuracy status.
        func locations() async {
            for await location in nmeaLocationDataSource.locations {
                guard let nmeaLocation = location as? NMEALocation,
                      nmeaLocationDataSource.status == .started else { return }
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
                    distanceFormatter.string(from: horizontalAccuracy),
                    distanceFormatter.string(from: verticalAccuracy)
                )
                accuracyStatus = accuracyText
            }
        }
        
        /// Starts iterating over satellite udpates and set the satellite status.
        func satellites() async {
            for await satellites in nmeaLocationDataSource.satellites {
                guard nmeaLocationDataSource.status == .started else { return }
                
                // Update the satellites info status text.
                let satelliteSystems = satellites.filter {
                    $0.system != nil
                }
                let satelliteSystemsText = ListFormatter.localizedString(
                    byJoining: Set(satellites.map(\.system!.label)).sorted()
                )
                let idText = ListFormatter.localizedString(
                    byJoining: satelliteSystems.map { String($0.id) }
                )
                satelliteStatus = String(
                    format: """
            %d satellites in view
            System(s): %@
            IDs: %@
            """,
                    satellites.count,
                    satelliteSystemsText,
                    idText
                )
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
