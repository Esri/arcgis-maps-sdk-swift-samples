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
import ArcGISToolkit

struct SetUpLocationDrivenGeotriggersView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    /// A Boolean value indicating whether to show the popup.
    @State private var isShowingPopup = false
    
    /// A string for the fence geotrigger notification status.
    @State private var fenceGeotriggerText = ""
    
    /// A string for the display name of the currently nearby feature.
    @State private var nearbyFeaturesText = ""
    
    /// Starts the geotrigger monitors and handles posted notifications.
    /// - Parameter geotriggerMonitors: The geotrigger monitors to start.
    private func startGeotriggerMonitors(_ geotriggerMonitors: [GeotriggerMonitor]) async throws {
        await withThrowingTaskGroup(of: Void.self) { group in
            for monitor in geotriggerMonitors {
                group.addTask {
                    try await monitor.start()
                    for await newNotification in monitor.notifications where newNotification is FenceGeotriggerNotificationInfo {
                        await model.handleGeotriggerNotification(newNotification as! FenceGeotriggerNotificationInfo)
                    }
                }
            }
        }
    }
    
    var body: some View {
        MapView(map: model.map)
            .locationDisplay(model.locationDisplay)
            .task {
                do {
                    // Load the map and its operational layers.
                    try await model.map.load()
                    
                    // Create the geotrigger monitors.
                    let monitors = model.makeGeotriggerMonitors()
                    
                    // Start geotrigger monitoring.
                    if !monitors.isEmpty {
                        try await startGeotriggerMonitors(monitors)
                    }
                } catch {
                    self.error = error
                }
            }
            .task(id: model.fenceGeotriggerStatus) {
                // Set fence geotrigger text.
                fenceGeotriggerText = model.fenceGeotriggerStatus.label
                
                // Set nearby features text.
                let features = model.nearbyFeatures
                if features.isEmpty {
                    nearbyFeaturesText = "No nearby features."
                } else {
                    nearbyFeaturesText = String(format: "Nearby: %@", ListFormatter.localizedString(byJoining: features.keys.sorted()))
                }
            }
            .overlay(alignment: .top) {
                // Status text overlay.
                VStack {
                    Text(fenceGeotriggerText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(nearbyFeaturesText)
                        .foregroundColor(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(8)
                .background(.thinMaterial, ignoresSafeAreaEdges: .horizontal)
            }
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button("Current Section") {
                        model.setSectionPopup()
                        isShowingPopup = true
                    }
                    .disabled(!model.hasCurrentSection)
                    .opacity(isShowingPopup ? 0 : 1)
                    
                    Button("Point of Interest") {
                        model.setPOIPopup()
                        isShowingPopup = true
                    }
                    .disabled(!model.hasPointOfInterest)
                    .opacity(isShowingPopup ? 0 : 1)
                }
            }
            .floatingPanel(
                selectedDetent: .constant(.full),
                horizontalAlignment: .leading,
                isPresented: $isShowingPopup
            ) {
                PopupView(popup: model.popup!, isPresented: $isShowingPopup)
                    .showCloseButton(true)
                    .padding()
            }
            .task(id: isShowingPopup) {
                if isShowingPopup {
                    // Stop location updates when the popup is showing.
                    await model.locationDisplay.dataSource.stop()
                } else {
                    // Start location updates when no popup is showing.
                    try? await model.locationDisplay.dataSource.start()
                }
            }
            .errorAlert(presentingError: $error)
    }
}

extension SetUpLocationDrivenGeotriggersView {
    /// The status of a fence geotrigger monitor.
    enum FenceGeotriggerStatus: Equatable {
        case notSet
        case entered(featureName: String)
        case exited(featureName: String)
        
        /// A human-readable label for the geotrigger status.
        var label: String {
            switch self {
            case .notSet:
                return "Fence geotrigger info will be shown here."
            case .entered(featureName: let featureName):
                return "Entered the geofence of \(featureName)"
            case .exited(featureName: let featureName):
                return "Exited the geofence of \(featureName)"
            }
        }
    }
}

#Preview {
    NavigationView {
        SetUpLocationDrivenGeotriggersView()
    }
}
