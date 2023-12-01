// Copyright 2023 Esri
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

import SwiftUI
import ArcGIS
import ExternalAccessory

struct ShowDeviceLocationWithNMEADataSourcesView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    /// A string for GPS accuracy.
    @State private var accuracyStatus = "Accuracy info will be shown here."
    
    /// A string for satellite information.
    @State private var satelliteStatus = "Satellites info will be shown here."
    
    /// A Boolean value specifying if the "recenter" button should be disabled.
    @State private var recenterButtonIsDisabled = true
    
    /// A Boolean value specifying if the "reset" button should be disabled.
    @State private var resetButtonIsDisabled = true
    
    /// A Boolean value specifying if the "source" button should be disabled.
    @State private var sourceMenuIsDisabled = false
    
    var body: some View {
        MapView(map: model.map)
            .locationDisplay(model.locationDisplay)
            .overlay(alignment: .top) {
                VStack(alignment: .leading) {
                    Text(accuracyStatus)
                    Text(satelliteStatus)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(.thinMaterial, ignoresSafeAreaEdges: .horizontal)
            }
            .task(id: model.sentenceReader.isStarted) {
                guard model.sentenceReader.isStarted else { return }
                // Push the mock data to the NMEA location data source.
                // This simulates the case where the NMEA messages coming from a hardware need to be
                // manually pushed to the data source.
                for await data in model.sentenceReader.messages {
                    // Push the data to the data source.
                    model.nmeaLocationDataSource?.pushData(data)
                }
            }
            .task(id: model.nmeaLocationDataSource?.status) {
                if let nmeaLocationDataSource = model.nmeaLocationDataSource, nmeaLocationDataSource.status == .started {
                    // Observe location display `autoPanMode` changes.
                    for await mode in model.locationDisplay.$autoPanMode {
                        recenterButtonIsDisabled = mode == .recenter
                    }
                } else {
                    recenterButtonIsDisabled = true
                }
            }
            .task(id: model.nmeaLocationDataSource?.status) {
                guard let nmeaLocationDataSource = model.nmeaLocationDataSource, nmeaLocationDataSource.status == .started else { return }
                // Observe location data source location changes.
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
                        horizontalAccuracy.formatted(model.formatStyle),
                        verticalAccuracy.formatted(model.formatStyle)
                    )
                    
                    accuracyStatus = accuracyText
                }
            }
            .task(id: model.nmeaLocationDataSource?.status) {
                guard let nmeaLocationDataSource = model.nmeaLocationDataSource, nmeaLocationDataSource.status == .started else { return }
                // Observe NMEA location data source's satellite changes.
                for await satellites in nmeaLocationDataSource.satellites {
                    // Update the satellites info status text.
                    let satelliteSystems = satellites.compactMap(\.system)
                    
                    let satelliteLabels = Set(satelliteSystems)
                        .map(\.label)
                        .sorted()
                        .formatted(model.listFormatStyle)
                    
                    let satelliteIDs = satellites
                        .map { String($0.id) }
                        .formatted(model.listFormatStyle)
                    
                    satelliteStatus = String(
                        format: """
                                %d satellites in view
                                System(s): %@
                                IDs: %@
                                """,
                        satellites.count,
                        satelliteLabels,
                        satelliteIDs
                    )
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Menu("Source") {
                        Button("Mock Data") {
                            Task {
                                do {
                                    try await model.start(usingMockedData: true)
                                    // Set buttons states.
                                    sourceMenuIsDisabled = true
                                    resetButtonIsDisabled = false
                                } catch {
                                    self.error = error
                                }
                            }
                        }
                        Button("Device") {
                            Task {
                                do {
                                    try selectDevice()
                                    try await model.start()
                                } catch {
                                    self.error = error
                                }
                            }
                        }
                    }
                    .disabled(sourceMenuIsDisabled)
                    Spacer()
                    Button("Recenter") {
                        model.locationDisplay.autoPanMode = .recenter
                    }
                    .disabled(recenterButtonIsDisabled)
                    Spacer()
                    Button("Reset") {
                        reset()
                    }
                    .disabled(resetButtonIsDisabled)
                }
            }
            .errorAlert(presentingError: $error)
            .onDisappear {
                reset()
            }
    }
    
    func reset() {
        // Reset the status text.
        accuracyStatus = "Accuracy info will be shown here."
        satelliteStatus = "Satellites info will be shown here."
        // Reset buttons states.
        resetButtonIsDisabled = true
        sourceMenuIsDisabled = false
        Task {
            // Reset the model to stop the data source and observations.
            await model.reset()
        }
    }
    
    func selectDevice() throws {
        if let (accessory, protocolString) = model.firstSupportedAccessoryWithProtocol() {
            // Use the supported accessory directly if it's already connected.
            model.accessoryDidConnect(connectedAccessory: accessory, protocolString: protocolString)
        } else {
            throw AccessoryError.noBluetoothDevices
        
            // NOTE: The code below shows how to use the built-in Bluetooth picker
            // to pair a device. However there are a couple of issues that
            // prevent the built-in picker from functioning as desired.
            // The work-around is to have the supported device connected prior
            // to running the sample. The above message will be displayed
            // if no devices with a supported protocol are connected.
            //
            // The Bluetooth accessory picker is currently not supported
            // for Apple Silicon devices - https://developer.apple.com/documentation/externalaccessory/eaaccessorymanager/1613913-showbluetoothaccessorypicker/
            // "On Apple silicon, this method displays an alert to let the user
            // know that the Bluetooth accessory picker is unavailable."
            //
            // Also, it appears that there is currently a bug with
            // `showBluetoothAccessoryPicker` - https://developer.apple.com/forums/thread/690320
            // The work-around is to ensure your device is already connected and it's
            // protocol is in the app's list of protocol strings in the plist.info table.
//            EAAccessoryManager.shared().showBluetoothAccessoryPicker(withNameFilter: nil) { error in
//                if let error = error as? EABluetoothAccessoryPickerError,
//                   error.code != .alreadyConnected {
//                    switch error.code {
//                    case .resultNotFound:
//                        self.error = AccessoryError.notFound
//                    case .resultCancelled:
//                        // Don't show error message when the picker is cancelled.
//                        return
//                    default:
//                        self.error = AccessoryError.unknown
//                    }
//                } else if let (accessory, protocolString) = model.firstSupportedAccessoryWithProtocol() {
//                    // Proceed with supported and connected accessory, and
//                    // ignore other accessories that aren't supported.
//                    model.accessoryDidConnect(connectedAccessory: accessory, protocolString: protocolString)
//                }
//            }
        }
    }
}

/// An error relating to NMEA accessories.
private enum AccessoryError: LocalizedError {
    /// No supported Bluetooth devices connected.
    case noBluetoothDevices
    /// Accessory could not be found.
    case notFound
    /// Unknown selection failure.
    case unknown
    
    /// The message describing what error occurred.
    var errorDescription: String? {
        let message: String
        switch self {
        case .noBluetoothDevices:
            message = "There are no supported Bluetooth devices connected. Open up \"Bluetooth Settings\", connect to your supported device, and try again."
        case .notFound:
            message = "The specified accessory could not be found, perhaps because it was turned off prior to connection."
        case .unknown:
            message = "Selecting an accessory failed for an unknown reason."
        }
        
        return NSLocalizedString(
            message,
            comment: "Error thrown when connecting an NMEA accessory fails."
        )
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
