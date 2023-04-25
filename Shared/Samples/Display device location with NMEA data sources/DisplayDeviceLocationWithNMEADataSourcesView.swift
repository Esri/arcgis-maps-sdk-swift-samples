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

struct DisplayDeviceLocationWithNMEADataSourcesView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// A Boolean value indicating whether to show an alert.
    @State private var isShowingAlert = false
    
    /// An error returned from the `EAAccessoryManager`.
    @State private var error: AccessoryError?
    
    var body: some View {
        // Creates a map view to display the map.
        MapView(map: model.map)
            .locationDisplay(model.locationDisplay)
            .overlay(alignment: .top) {
                VStack(alignment: .leading) {
                    Text(model.accuracyStatus)
                    Text(model.satelliteStatus)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(.thinMaterial, ignoresSafeAreaEdges: .horizontal)
            }
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Menu("Source") {
                        Button("Mock Data") {
                            model.start(usingMockedData: true)
                        }
                        Button("Device") {
                            selectDevice()
                        }
                    }
                    .disabled(model.isSourceMenuDisabled)
                    Spacer()
                    Button("Recenter") {
                        model.autoPanMode = .recenter
                    }
                    .disabled(model.isRecenterButtonDisabled)
                    Spacer()
                    Button("Reset") {
                        model.reset()
                    }
                    .disabled(model.isResetButtonDisabled)
                }
            }
            .accessoryAlert(isPresented: $isShowingAlert, presentingError: error)
            .onDisappear {
                // Reset the model to stop the data source and observations.
                model.reset()
            }
    }
    
    func selectDevice() {
        if let (accessory, protocolString) = model.firstSupportedAccessoryWithProtocol() {
            // Use the supported accessory directly if it's already connected.
            model.accessoryDidConnect(connectedAccessory: accessory, protocolString: protocolString)
        } else {
            // Show a picker to pair the device with a Bluetooth accessory.
            // NOTE: the Bluetooth accessory picker is currently not supported
            // for Apple Silicon devices - https://developer.apple.com/documentation/externalaccessory/eaaccessorymanager/1613913-showbluetoothaccessorypicker/
            // "On Apple silicon, this method displays an alert to let the user
            // know that the Bluetooth accessory picker is unavailable."
            // Also, it appears that there is currently a bug with
            // `showBluetoothAccessoryPicker` - https://developer.apple.com/forums/thread/690320
            // The work-around is to ensure your device is already connected and it's
            // protocol is in the app's list of protocol strings in the plist.info table.
            EAAccessoryManager.shared().showBluetoothAccessoryPicker(withNameFilter: nil) { error in
                if let error = error as? EABluetoothAccessoryPickerError,
                   error.code != .alreadyConnected {
                    switch error.code {
                    case .resultNotFound:
                        self.error = AccessoryError(detail: "The specified accessory could not be found, perhaps because it was turned off prior to connection.")
                    case .resultCancelled:
                        // Don't show error message when the picker is cancelled.
                        self.error = nil
                        return
                    default:
                        self.error = AccessoryError(detail: "Selecting an accessory failed for an unknown reason.")
                    }
                    isShowingAlert = (self.error != nil)
                } else if let (accessory, protocolString) = model.firstSupportedAccessoryWithProtocol() {
                    // Proceed with supported and connected accessory, and
                    // ignore other accessories that aren't supported.
                    model.accessoryDidConnect(connectedAccessory: accessory, protocolString: protocolString)
                }
            }
        }
    }
}

/// An error relating to NMEA accessories.
struct AccessoryError: Error {
    let detail: String
}

extension View {
    /// Shows an alert with the title "Error", the error's `details`
    /// as the message, and an OK button.
    /// - Parameters:
    ///   - isPresented: A binding to a Boolean value that determines whether
    ///   to present the alert. When the user taps one of the alert’s actions,
    ///   the system sets this value to false and dismisses the alert.
    ///   - error: An ``AccessoryError`` to be shown in the alert.
    func accessoryAlert(isPresented: Binding<Bool>, presentingError error: AccessoryError?) -> some View {
        alert("Error", isPresented: isPresented, presenting: error) { _ in
            EmptyView()
        } message: { error in
            Text(error.detail)
        }
    }
}
