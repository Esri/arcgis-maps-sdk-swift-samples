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

import ArcGIS
import ArcGISToolkit
import SwiftUI

struct SetUpLocationDrivenGeotriggersView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// The error shown in the error alert.
    @State private var error: (any Error)?
    
    /// A Boolean value indicating whether to show the popup.
    @State private var isShowingPopup = false
    
    /// Starts the geotrigger monitors and handles posted notifications.
    /// - Parameter geotriggerMonitors: The geotrigger monitors to start.
    private func startGeotriggerMonitors(_ geotriggerMonitors: [GeotriggerMonitor]) async throws {
        await withThrowingTaskGroup(of: Void.self) { group in
            for monitor in geotriggerMonitors {
                group.addTask { @MainActor @Sendable in
                    for await newNotification in monitor.notifications where newNotification is FenceGeotriggerNotificationInfo {
                        model.handleGeotriggerNotification(newNotification as! FenceGeotriggerNotificationInfo)
                    }
                }
                
                group.addTask {
                    try await monitor.start()
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
            .overlay(alignment: .top) {
                // Status text overlay.
                VStack {
                    Text(model.fenceGeotriggerStatus.label)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    let nearbyFeatures = model.nearbyFeatures
                    let nearbyFeaturesText = if !nearbyFeatures.isEmpty {
                        Text("Nearby: \(nearbyFeatures.keys.sorted(), format: .list(type: .and))")
                    } else {
                        Text("No nearby features.")
                    }
                    nearbyFeaturesText
                        .foregroundStyle(.orange)
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
                    
                    Button("Point of Interest") {
                        model.setPOIPopup()
                        isShowingPopup = true
                    }
                    .disabled(!model.hasPointOfInterest)
                }
            }
            .sheet(isPresented: $isShowingPopup) {
                PopupView(root: model.popup!, isPresented: $isShowingPopup)
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
    NavigationStack {
        SetUpLocationDrivenGeotriggersView()
    }
}
