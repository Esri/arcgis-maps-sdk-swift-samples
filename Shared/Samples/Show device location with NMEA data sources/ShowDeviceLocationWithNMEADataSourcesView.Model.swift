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
import Combine
import ExternalAccessory

extension ShowDeviceLocationWithNMEADataSourcesView {
    /// The model used to store the geo model and other expensive objects used in this view.
    @MainActor
    class Model: ObservableObject {
        // MARK: Properties
        
        /// A map with a navigation basemap.
        let map = Map(basemapStyle: .arcGISNavigation)
        
        /// The location display used in the map view.
        let locationDisplay: LocationDisplay = {
            let locationDisplay = LocationDisplay()
            locationDisplay.autoPanMode = .recenter
            return locationDisplay
        }()
        
        /// An NMEA location data source, to parse NMEA data.
        private(set) var nmeaLocationDataSource: NMEALocationDataSource?
        
        /// A mock data reader to read NMEA sentences from a local file, and generate
        /// mock NMEA data every fixed amount of time.
        let sentenceReader = FileNMEASentenceReader(
            url: Bundle.main.url(forResource: "Redlands", withExtension: "nmea")!,
            interval: 0.66
        )
        
        /// A format style for the accuracy distance string.
        let formatStyle = Measurement<UnitLength>.FormatStyle.measurement(
            width: .abbreviated,
            usage: .general,
            numberFormatStyle: .number.precision(.fractionLength(1))
        )
        
        /// A format style for concatenating an array of text.
        let listFormatStyle = ListFormatStyle<StringStyle, Array>.list(type: .and, width: .narrow)
        
        /// The protocols used in this sample to get NMEA sentences.
        /// They are also specified in the `Info.plist` to allow the app to
        /// communicate with external accessory hardware.
        private let supportedProtocolStrings: Set = [
            "com.bad-elf.gps",
            "com.eos-gnss.positioningsource",
            "com.geneq.sxbluegpssource"
        ]
        
        // MARK: Methods
        
        /// Gets the first connected and supported Bluetooth accessory with its
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
            }
        }
        
        /// Resets the sample, stops the data source and mock data generation.
        func reset() async {
            // Reset NMEA location data source.
            nmeaLocationDataSource = nil
            locationDisplay.autoPanMode = .off
            
            // Stop the location display, which in turn stop the data source.
            await locationDisplay.dataSource.stop()
            
            // Pause the mock data generation.
            sentenceReader.stop()
        }
        
        /// Starts the location data source and awaits location and satellite updates.
        /// - Parameter usingMockedData: `true` for the location datasource to use mocked data.
        func start(usingMockedData: Bool = false) async throws {
            if usingMockedData {
                nmeaLocationDataSource = NMEALocationDataSource(receiverSpatialReference: .wgs84)
                // Start the mock data generation.
                sentenceReader.start()
            }
            
            // Set NMEA location data source for location display.
            guard let nmeaLocationDataSource else { return }
            locationDisplay.dataSource = nmeaLocationDataSource
            
            // Set the autopan mode to `.recenter`
            locationDisplay.autoPanMode = .recenter
            
            // Start the data source.
            try await locationDisplay.dataSource.start()
        }
    }
}
