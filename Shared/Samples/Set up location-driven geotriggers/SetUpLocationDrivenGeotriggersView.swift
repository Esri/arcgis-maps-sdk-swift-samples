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
    
    /// The popup to show the feature information.
    @State private var popup: Popup?
    
    /// A Boolean value indicating whether to show the popup.
    @State var isShowingPopup = false
    
    var body: some View {
        MapView(map: model.map)
            .locationDisplay(model.locationDisplay)
            .task {
                // Start geotrigger monitoring once the map loads.
                do {
                    try await model.map.load()
                    model.startGeotriggerMonitoring()
                } catch {
                    model.error = error
                }
            }
            .overlay(alignment: .top) {
                // Status text overlay.
                VStack {
                    Text(model.fenceGeotriggerText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(model.nearbyFeaturesText)
                        .foregroundColor(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(8)
                .background(.thinMaterial, ignoresSafeAreaEdges: .horizontal)
            }
            .toolbar {
                // Bottom button toolbar.
                ToolbarItemGroup(placement: .bottomBar) {
                    Button("Current Section") {
                        let sectionFeature = model.nearbyFeatures[model.currentSectionName!]!
                        popup = Popup(geoElement: sectionFeature)
                        isShowingPopup = true
                    }
                    .disabled(!model.hasCurrentSection)
                    .opacity(isShowingPopup ? 0 : 1)
                    
                    Button("Point of Interest") {
                        let poiFeature = model.nearbyFeatures[model.nearbyPOINames.first!]!
                        popup = Popup(geoElement: poiFeature)
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
                Group {
                    // Feature info popup.
                    if let popup = popup {
                        PopupView(popup: popup, isPresented: $isShowingPopup)
                            .showCloseButton(true)
                    }
                }
                .padding()
            }
            .task(id: isShowingPopup) {
                // Stop location updates when the popup is showing.
                if isShowingPopup {
                    await model.locationDisplay.dataSource.stop()
                } else {
                    try? await model.locationDisplay.dataSource.start()
                }
            }
            .alert(isPresented: $model.isShowingAlert, presentingError: model.error)
    }
}
