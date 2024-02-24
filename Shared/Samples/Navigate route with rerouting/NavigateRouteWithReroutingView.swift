// Copyright 2024 Esri
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

struct NavigateRouteWithReroutingView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// The navigation action currently being run.
    @State private var selectedNavigationAction: NavigationAction? = .setUp
    
    /// A Boolean value indicating whether the navigation can be reset.
    @State private var canReset = false
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    var body: some View {
        MapView(
            map: model.map,
            viewpoint: model.viewpoint,
            graphicsOverlays: [model.graphicsOverlay]
        )
        .onViewpointChanged(kind: .centerAndScale) { model.viewpoint = $0 }
        .locationDisplay(model.locationDisplay)
        .overlay(alignment: .top) {
            Text(model.statusMessage)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(8)
                .background(.thinMaterial, ignoresSafeAreaEdges: .horizontal)
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button {
                    selectedNavigationAction = .reset
                } label: {
                    Image(systemName: "gobackward")
                }
                .disabled(!canReset)
                
                Spacer()
                Button {
                    selectedNavigationAction = model.isNavigating ? .stop : .start
                } label: {
                    Image(systemName: model.isNavigating ? "pause.fill" : "play.fill")
                }
                .disabled(
                    selectedNavigationAction == .setUp
                    || model.routeTracker.trackingStatus?.destinationStatus == .reached
                )
                
                Spacer()
                Button {
                    model.locationDisplay.autoPanMode = .navigation
                } label: {
                    Image(systemName: "location.fill")
                }
                .disabled(!model.isNavigating || model.locationDisplay.autoPanMode == .navigation)
            }
        }
        .task(id: selectedNavigationAction) {
            guard let selectedNavigationAction else { return }
            defer { self.selectedNavigationAction = nil }
            
            do {
                // Run the new action.
                switch selectedNavigationAction {
                case .setUp:
                    try await model.setUp()
                    
                case .start:
                    try await model.start()
                    canReset = true
                    
                case .stop:
                    await model.stop()
                    
                case .reset:
                    try await model.reset()
                    canReset = false
                }
            } catch {
                self.error = error
            }
        }
        .task(id: model.isNavigating) {
            guard model.isNavigating, let routeTracker = model.routeTracker else { return }
            
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    // Handle new tracking statuses from the route tracker.
                    for await trackingStatus in routeTracker.$trackingStatus {
                        guard let trackingStatus else { continue }
                        await model.updateProgress(using: trackingStatus)
                    }
                }
                
                group.addTask {
                    // Speak new voice guidances from the route tracker.
                    for await voiceGuidance in routeTracker.voiceGuidances {
                        await model.speakVoiceGuidance(voiceGuidance)
                    }
                }
            }
        }
        .errorAlert(presentingError: $error)
    }
}

private extension NavigateRouteWithReroutingView {
    /// An enumeration representing an action relating to the navigation.
    enum NavigationAction {
        /// Set up the route.
        case setUp
        /// Start navigating.
        case start
        /// Stop navigating.
        case stop
        /// Reset the route.
        case reset
    }
}
