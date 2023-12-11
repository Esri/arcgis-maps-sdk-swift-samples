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
import CoreLocation
import SwiftUI

struct ShowDeviceLocationView: View {
    /// The error shown in the error alert.
    @State private var error: Error?
    
    /// A Boolean value indicating whether the settings button is disabled.
    @State private var settingsButtonIsDisabled = true
    
    /// The view model for this sample.
    @StateObject private var model = Model()
    
    var body: some View {
        MapView(map: model.map)
            .locationDisplay(model.locationDisplay)
            .task {
                guard model.locationDisplay.dataSource.status != .started else {
                    return
                }
                do {
                    try await model.startLocationDataSource()
                    settingsButtonIsDisabled = false
                    // Updates the current auto-pan mode if it does not match the
                    // location display's auto-pan mode.
                    for await mode in model.locationDisplay.$autoPanMode {
                        if model.autoPanMode != mode {
                            model.autoPanMode = mode
                        }
                    }
                } catch {
                    // Shows an alert with an error if starting the data source fails.
                    self.error = error
                }
            }
            .onDisappear {
                model.stopLocationDataSource()
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Menu("Location Settings") {
                        Toggle("Show Location", isOn: $model.isShowingLocation)
                        
                        Picker("Auto-Pan Mode", selection: $model.autoPanMode) {
                            ForEach(LocationDisplay.AutoPanMode.allCases, id: \.self) { mode in
                                Label(mode.label, image: mode.imageName)
                                    .imageScale(.large)
                            }
                        }
                    }
                    .disabled(settingsButtonIsDisabled)
                }
            }
            .errorAlert(presentingError: $error)
    }
}

private extension ShowDeviceLocationView {
    /// The model used to store the geo model and other expensive objects
    /// used in this view.
    @MainActor
    class Model: ObservableObject {
        /// A Boolean value indicating whether to show the device location.
        @Published var isShowingLocation: Bool {
            didSet {
                locationDisplay.showsLocation = isShowingLocation
            }
        }
        
        /// The current auto-pan mode.
        @Published var autoPanMode: LocationDisplay.AutoPanMode {
            didSet {
                locationDisplay.autoPanMode = autoPanMode
            }
        }
        
        /// A map with a standard imagery basemap style.
        let map = Map(basemapStyle: .arcGISImageryStandard)
        
        /// A location display using the system location data source.
        let locationDisplay: LocationDisplay
        
        init() {
            let locationDisplay = LocationDisplay(dataSource: SystemLocationDataSource())
            self.locationDisplay = locationDisplay
            self.isShowingLocation = locationDisplay.showsLocation
            self.autoPanMode = locationDisplay.autoPanMode
        }
        
        /// Starts the location data source.
        func startLocationDataSource() async throws {
            // Requests location permission if it has not yet been determined.
            let locationManager = CLLocationManager()
            if locationManager.authorizationStatus == .notDetermined {
                locationManager.requestWhenInUseAuthorization()
            }
            // Starts the location display data source.
            try await locationDisplay.dataSource.start()
        }
        
        /// Stops the location data source.
        func stopLocationDataSource() {
            Task {
                await locationDisplay.dataSource.stop()
            }
        }
    }
}

private extension LocationDisplay.AutoPanMode {
    /// A human-readable label for each auto-pan mode.
    var label: String {
        switch self {
        case .off: return "Autopan Off"
        case .recenter: return "Recenter"
        case .navigation: return "Navigation"
        case .compassNavigation: return "Compass Navigation"
        @unknown default: return "Unknown"
        }
    }
    
    /// The image name for each auto-pan mode.
    var imageName: String {
        switch self {
        case .off: return "LocationDisplayOffIcon"
        case .recenter: return "LocationDisplayDefaultIcon"
        case .navigation: return "LocationDisplayNavigationIcon"
        case .compassNavigation: return "LocationDisplayHeadingIcon"
        @unknown default: return "LocationDisplayOffIcon"
        }
    }
}

#Preview {
    NavigationView {
        ShowDeviceLocationView()
    }
}
