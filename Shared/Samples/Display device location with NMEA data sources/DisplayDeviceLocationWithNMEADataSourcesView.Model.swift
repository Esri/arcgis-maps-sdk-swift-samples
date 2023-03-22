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
    class Model: ObservableObject {
        /// A map with imagery basemap.
        let map = Map(basemapStyle: .arcGISImagery)
        
        @State var autoPanMode: LocationDisplay.AutoPanMode = .recenter
        
        @State var isRecenterButtonEnabled = false
        
        @State var isResetButtonEnabled = false
        
        @State var isSourceButtonEnabled = true
        
        @State var accuracyStatus: String = ""
        
        @State var satelliteStatus: String = ""
        
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
//            var dataSource =
//            locationDispay = LocationDisplay(dataSource: dataSource)
        }
        
        func recenter() {
            autoPanMode = .recenter
            isRecenterButtonEnabled = false
            
//            mapView.locationDisplay.autoPanModeChangedHandler = { [weak self] _ in
//                DispatchQueue.main.async {
//                    self?.recenterBarButtonItem.isEnabled = true
//                }
//                self?.mapView.locationDisplay.autoPanModeChangedHandler = nil
//            }
        }
        
        func reset() {
            // Reset buttons states.
            isResetButtonEnabled = false
            isSourceButtonEnabled = true
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
        
        @IBAction func chooseDataSource(_ sender: UIBarButtonItem) {
            let alertController = UIAlertController(
                title: "Choose an NMEA data source.",
                message: nil,
                preferredStyle: .actionSheet
            )
            // Add real data source to the options.
            let realDataSourceAction = UIAlertAction(title: "Device", style: .default) { [unowned self] _ in
                if let (accessory, protocolString) = firstSupportedAccessoryWithProtocol() {
                    // Use the supported accessory directly if it's already connected.
                    accessoryDidConnect(connectedAccessory: accessory, protocolString: protocolString)
                } else {
                    // Show a picker to pair the device with a Bluetooth accessory.
                    EAAccessoryManager.shared().showBluetoothAccessoryPicker(withNameFilter: nil) { error in
                        if let error = error as? EABluetoothAccessoryPickerError,
                           error.code != .alreadyConnected {
                            switch error.code {
                            case .resultNotFound:
                                print("presentalert")
//                                self.presentAlert(message: "The specified accessory could not be found, perhaps because it was turned off prior to connection.")
                            case .resultCancelled:
                                // Don't show error message when the picker is cancelled.
                                return
                            default:
                                print("default presentalert")
//                                self.presentAlert(message: "Selecting an accessory failed for an unknown reason.")
                            }
                        } else if let (accessory, protocolString) = self.firstSupportedAccessoryWithProtocol() {
                            // Proceed with supported and connected accessory, and
                            // ignore other accessories that aren't supported.
                            self.accessoryDidConnect(connectedAccessory: accessory, protocolString: protocolString)
                        }
                    }
                }
            }
            alertController.addAction(realDataSourceAction)
            // Add mock data source to the options.
            let mockDataSourceAction = UIAlertAction(title: "Mock Data", style: .default) { [unowned self] _ in
                nmeaLocationDataSource = NMEALocationDataSource(receiverSpatialReference: .wgs84)
//                nmeaLocationDataSource.locationChangeHandlerDelegate = self
//                mockNMEADataSource.delegate = self
                start()
            }
            alertController.addAction(mockDataSourceAction)
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
            alertController.addAction(cancelAction)
            alertController.popoverPresentationController?.barButtonItem = sender
//            present(alertController, animated: true)
        }
        
        func start() {
            // Set NMEA location data source for location display.
            locationDisplay.dataSource = nmeaLocationDataSource
            // Set buttons states.
            isSourceButtonEnabled = false
            isResetButtonEnabled = true
            // Start the data source and location display.
            mockNMEADataSource.start()
            Task {
                try? await nmeaLocationDataSource.start()
                // Recenter the map and set pan mode.
                recenter()
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
