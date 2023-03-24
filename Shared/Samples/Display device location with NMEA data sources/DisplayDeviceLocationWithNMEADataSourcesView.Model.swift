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
        let map = Map(basemapStyle: .arcGISImagery)
        
        var autoPanMode: LocationDisplay.AutoPanMode = .recenter {
            didSet {
                locationDisplay.autoPanMode = autoPanMode
                isRecenterButtonDisabled = autoPanMode == .recenter
            }
        }
        
        @Published var isRecenterButtonDisabled = true
        
        @Published var isResetButtonDisabled = true
        
        @Published var isSourceButtonDisabled = false
        
        @Published var accuracyStatus: String = "Accuracy info will be shown here."
        
        @Published var satelliteStatus: String = "Satellites info will be shown here."
        
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
                for await mode in locationDisplay.$autoPanMode {
                    if autoPanMode != mode {
                        autoPanMode = mode
                    }
                }
            }
        }
        
        func recenter() {
            autoPanMode = .recenter
        }
        
        func reset() {
            // Reset buttons states.
            isResetButtonDisabled = true
            isSourceButtonDisabled = false
            // Reset the status text.
            accuracyStatus = "Accuracy info will be shown here."
            satelliteStatus = "Satellites info will be shown here."
            
            // Reset and stop the location display.
            //            mapView.locationDisplay.autoPanModeChangedHandler = nil
            autoPanMode = .off
            
            Task {
                // Stop the location display, which in turn stop the data source.
                await nmeaLocationDataSource.stop()
                
                // Reset NMEA location data source.
                nmeaLocationDataSource = nil
            }
            
            // Pause the mock data generation.
            mockNMEADataSource.stop()
            //            // Disconnect from the mock data updates.
            //            mockNMEADataSource.delegate = nil
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
        func accessoryDidConnect(connectedAccessory: EAAccessory, protocolString: String) {
            if let dataSource = NMEALocationDataSource(accessory: connectedAccessory, protocol: protocolString) {
                nmeaLocationDataSource = dataSource
                //                nmeaLocationDataSource.locationChangeHandlerDelegate = self
                start()
            } else {
                //                presentAlert(message: "NMEA location data source failed to initialize from the accessory!")
            }
        }
        
        func start() {
            // Set NMEA location data source for location display.
            locationDisplay.dataSource = nmeaLocationDataSource
            // Set buttons states.
            isSourceButtonDisabled = true
            isResetButtonDisabled = false
            
            // Start the data source and location display.
            mockNMEADataSource.start(with: nmeaLocationDataSource)
            Task {
                try? await nmeaLocationDataSource.start()
                // Recenter the map and set pan mode.
                recenter()
                
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
                        distanceFormatter.string(from: horizontalAccuracy),
                        distanceFormatter.string(from: verticalAccuracy)
                    )
                    accuracyStatus = accuracyText
                }
                
            TODO: figure out why satellite info doesn't show up
                for await satellites in nmeaLocationDataSource.satellites {
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

private extension URL {
    /// The URL for the world elevation service.
    static var worldElevationService: URL {
        URL(string: "https://elevation3d.arcgis.com/arcgis/rest/services/WorldElevation3D/Terrain3D/ImageServer")!
    }
    
    /// The URL for the 3D buildings layer in Brest, France.
    static var brestBuildingsLayer: URL {
        URL(string: "https://tiles.arcgis.com/tiles/P3ePLMYs2RVChkJx/arcgis/rest/services/Buildings_Brest/SceneServer/layers/0")!
    }
}
