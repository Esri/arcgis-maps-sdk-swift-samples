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
    /// A Boolean value indicating whether to show an alert.
    @State private var showAlert = false
    
    /// The error to display in the alert.
    @State private var error: Error?
    
    /// A Boolean value indicating whether to device location.
    @State private var showLocation = false
    
    /// The current auto-pan mode.
    @State private var autoPanMode = LocationDisplay.AutoPanMode.off
    
    /// A map with a standard imagery basemap style.
    @StateObject private var map = Map(basemapStyle: .arcGISImageryStandard)
    
    /// The `CLLocationManager` used to request location permissions.
    private let locationManager = CLLocationManager()
    
    /// A location display using the system location data source.
    private let locationDisplay = LocationDisplay(dataSource: SystemLocationDataSource())
    
    /// Starts the location data source.
    private func startLocationDataSource() async {
        // Requests location permission if it has not yet been determined.
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        do {
            // Starts the location display data source.
            try await locationDisplay.dataSource.start()
            
            locationDisplay.showLocation = showLocation
            locationDisplay.autoPanMode = autoPanMode
        } catch {
            // Shows an alert with an error if starting the data source fails.
            self.error = error
            self.showAlert = true
        }
    }
    
    var body: some View {
        VStack {
            MapView(map: map)
                .locationDisplay(locationDisplay)
                .onReceive(locationDisplay.$autoPanMode) { mode in
                    // Updates the auto-pan mode when an update is received.
                    autoPanMode = mode
                }
                .task {
                    await startLocationDataSource()
                }
                .onDisappear {
                    Task {
                        // Stops the location data source.
                        await locationDisplay.dataSource.stop()
                    }
                }
            
            Menu("Location Settings") {
                Toggle("Show Location", isOn: Binding(get: {
                    showLocation
                }, set: {
                    showLocation = $0
                    // Updates the location display's show location value.
                    locationDisplay.showLocation = showLocation
                }))
                
                Picker(
                    "Auto-Pan Mode",
                    selection: Binding(
                        get: {
                            autoPanMode
                        },
                        set: {
                            autoPanMode = $0
                            // Updates the location display's auto-pan mode.
                            locationDisplay.autoPanMode = autoPanMode
                        }
                    )
                ) {
                    ForEach(LocationDisplay.AutoPanMode.allCases, id: \.self) { mode in
                        Label(mode.label, image: mode.imageName)
                            .imageScale(.large)
                    }
                }
            }
            .padding()
        }
        .alert(isPresented: $showAlert, presentingError: error)
    }
}

private extension LocationDisplay.AutoPanMode {
    static var allCases: [LocationDisplay.AutoPanMode] = [.off, .recenter, .navigation, .compassNavigation]
    
    var label: String {
        switch self {
        case .off: return "Off"
        case .recenter: return "Recenter"
        case .navigation: return "Navigation"
        case .compassNavigation: return "Compass Navigation"
        }
    }
    
    var imageName: String {
        switch self {
        case .off: return "LocationDisplayOffIcon"
        case .recenter: return "LocationDisplayDefaultIcon"
        case .navigation: return "LocationDisplayNavigationIcon"
        case .compassNavigation: return "LocationDisplayHeadingIcon"
        }
    }
}
