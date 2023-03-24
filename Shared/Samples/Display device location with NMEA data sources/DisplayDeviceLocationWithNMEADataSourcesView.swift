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
    
    /// A Boolean value indicating whether the source sheet is being shown or not.
    @State private var shouldShowSource = false
    
    /// A Boolean value indicating whether to show an alert.
    @State private var isShowingAlert = false
    
    /// An error returned from the `EAAccessoryManager`.
    @State private var error: Error?
    
    var body: some View {
        // Creates a map view to display the map.
        MapView(map: model.map)
            .locationDisplay(model.locationDisplay)
            .overlay(alignment: .top) {
                VStack {
                    Text(model.accuracyStatus)
                    Text(model.satelliteStatus)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(.thinMaterial, ignoresSafeAreaEdges: .horizontal)
            }
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Spacer()
                    Button("Source") {
                        shouldShowSource = true
                    }
                    .disabled(model.isSourceButtonDisabled)
                    Spacer()
                    Button("Recenter") {
                        model.recenter()
                    }
                    .disabled(model.isRecenterButtonDisabled)
                    Spacer()
                    Button("Reset") {
                        model.reset()
                    }
                    .disabled(model.isResetButtonDisabled)
                }
            }
            .alert(isPresented: $isShowingAlert, presentingError: error)
            .confirmationDialog("Choose an NMEA data source.", isPresented: $shouldShowSource, titleVisibility: .visible) {
                Button("Device") {
                    if let (accessory, protocolString) = model.firstSupportedAccessoryWithProtocol() {
                        // Use the supported accessory directly if it's already connected.
                        model.accessoryDidConnect(connectedAccessory: accessory, protocolString: protocolString)
                    } else {
                        // Show a picker to pair the device with a Bluetooth accessory.
                        EAAccessoryManager.shared().showBluetoothAccessoryPicker(withNameFilter: nil) { error in
                            if let error = error as? EABluetoothAccessoryPickerError,
                               error.code != .alreadyConnected {
                                self.error = error
                                isShowingAlert = true
//                                switch error.code {
//                                case .resultNotFound:
//                                    self.presentAlert(message: "The specified accessory could not be found, perhaps because it was turned off prior to connection.")
//                                case .resultCancelled:
//                                    // Don't show error message when the picker is cancelled.
//                                    return
//                                default:
//                                    self.presentAlert(message: "Selecting an accessory failed for an unknown reason.")
//                                }
                            } else if let (accessory, protocolString) = model.firstSupportedAccessoryWithProtocol() {
                                // Proceed with supported and connected accessory, and
                                // ignore other accessories that aren't supported.
                                model.accessoryDidConnect(connectedAccessory: accessory, protocolString: protocolString)
                            }
                        }
                    }
                }
                
                Button("Mock Data") {
                    model.nmeaLocationDataSource = NMEALocationDataSource(receiverSpatialReference: .wgs84)
                    //                            nmeaLocationDataSource.locationChangeHandlerDelegate = self
                    //                            mockNMEADataSource.delegate = self
                    model.start()
                }
            }
    }
}
