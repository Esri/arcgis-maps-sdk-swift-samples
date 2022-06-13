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
    @State private var showAlert = false
    
    @State private var error: Error?
    
    @State private var showLocation = false
    
//    @State private var locationDisplay = LocationDisplay(dataSource: SystemLocationDataSource())
    
    @StateObject private var map = Map(basemapStyle: .arcGISImageryStandard)
    
    private let locationManager = CLLocationManager()
    
    private let locationDisplay = LocationDisplay(dataSource: SystemLocationDataSource())
    
    private func startLocationData() async {
        // Requests location permission if it has not yet been determined
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        do {
            try await locationDisplay.dataSource.start()
            
            locationDisplay.showLocation = showLocation
            locationDisplay.autoPanMode = autoPanMode
        } catch {
            self.error = error
            self.showAlert = true
        }
    }
    
    var body: some View {
        VStack {
            MapView(map: map)
                .locationDisplay(locationDisplay)
                .task {
                    await startLocationData()
                }
                .gesture(
                    DragGesture()
                        .onChanged { _ in
                            // Sets the autopan mode to off when the map is dragged.
//                            if autoPanMode != .off {
                            autoPanMode = .off
                            locationDisplay.autoPanMode = autoPanMode
                        }
                )
                .onDisappear {
                    Task {
                        // Stops the location data source.
                        await locationDisplay.dataSource.stop()
                    }
                }
            
            Menu("Location Settings") {
                Toggle(isOn: Binding(
                    get: {
                        showLocation
                    },
                    set: {
                        showLocation = $0
                        // Updates the location display's show location value.
                        locationDisplay.showLocation = showLocation
                    })
                ) {
                    Text("Show Location")
                }
                
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
