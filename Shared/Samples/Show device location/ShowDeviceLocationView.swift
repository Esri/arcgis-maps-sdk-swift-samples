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

import SwiftUI
import ArcGIS
import CoreLocation

struct ShowDeviceLocationView: View {
    /// The view model for this sample.
    @StateObject private var model = Model()
    
    var body: some View {
        MapView(map: model.map)
            .locationDisplay(model.locationDisplay)
            .task {
                await model.startLocationDataSource()
                await model.updateAutoPanMode()
            }
            .onDisappear {
                model.stopLocationDataSource()
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Menu("Location Settings") {
                        Toggle("Show Location", isOn: $model.showLocation)
                        
                        Picker("Auto-Pan Mode", selection: $model.autoPanMode) {
                            ForEach(LocationDisplay.AutoPanMode.allCases, id: \.self) { mode in
                                Label(mode.label, image: mode.imageName)
                                    .imageScale(.large)
                            }
                        }
                    }
                    .disabled(model.settingsDisabled)
                }
            }
            .alert(isPresented: $model.showAlert, presentingError: model.error)
    }
}

private extension ShowDeviceLocationView {
    /// The view model for this sample.
    @MainActor private class Model: ObservableObject {
        /// A Boolean value indicating whether to show the device location.
        @Published var showLocation: Bool {
            didSet {
                locationDisplay.showLocation = showLocation
            }
        }
        
        /// The current auto-pan mode.
        @Published var autoPanMode: LocationDisplay.AutoPanMode {
            didSet {
                locationDisplay.autoPanMode = autoPanMode
            }
        }
        
        /// A Boolean value indicating whether the settings button is disabled.
        @Published var settingsDisabled = true
        
        /// A Boolean value indicating whether to show an alert.
        @Published var showAlert = false
        
        /// The error to display in the alert.
        var error: Error?
        
        /// A map with a standard imagery basemap style.
        let map = Map(basemapStyle: .arcGISImageryStandard)
        
        /// A location display using the system location data source.
        let locationDisplay: LocationDisplay
        
        init() {
            let locationDisplay = LocationDisplay(dataSource: SystemLocationDataSource())
            self.locationDisplay = locationDisplay
            self.showLocation = locationDisplay.showLocation
            self.autoPanMode = locationDisplay.autoPanMode
        }
        
        /// Starts the location data source.
        func startLocationDataSource() async {
            // Requests location permission if it has not yet been determined.
            let locationManager = CLLocationManager()
            if locationManager.authorizationStatus == .notDetermined {
                locationManager.requestWhenInUseAuthorization()
            }
            do {
                // Starts the location display data source.
                try await locationDisplay.dataSource.start()
                settingsDisabled = false
            } catch {
                // Shows an alert with an error if starting the data source fails.
                self.error = error
                showAlert = true
            }
        }
        
        /// Stops the location data source.
        func stopLocationDataSource() {
            Task {
                await locationDisplay.dataSource.stop()
            }
        }
        
        /// Updates the current auto-pan mode if it does not match the location display's auto-pan mode.
        func updateAutoPanMode() async {
            for await mode in locationDisplay.$autoPanMode {
                if autoPanMode != mode {
                    autoPanMode = mode
                }
            }
        }
    }
}

private extension LocationDisplay.AutoPanMode {
    static var allCases: [LocationDisplay.AutoPanMode] { [.off, .recenter, .navigation, .compassNavigation] }
    
    /// A human-readable label for each auto-pan mode.
    var label: String {
        switch self {
        case .off: return "Off"
        case .recenter: return "Recenter"
        case .navigation: return "Navigation"
        case .compassNavigation: return "Compass Navigation"
        }
    }
    
    /// The image name for each auto-pan mode.
    var imageName: String {
        switch self {
        case .off: return "LocationDisplayOffIcon"
        case .recenter: return "LocationDisplayDefaultIcon"
        case .navigation: return "LocationDisplayNavigationIcon"
        case .compassNavigation: return "LocationDisplayHeadingIcon"
        }
    }
}
