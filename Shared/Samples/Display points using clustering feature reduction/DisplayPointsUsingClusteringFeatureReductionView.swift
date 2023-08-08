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
import SwiftUI
import ArcGISToolkit

struct DisplayPointsUsingClusteringFeatureReductionView: View {
    /// A map of global power plants.
    @State private var map = {
        let portalItem = PortalItem(
            portal: .arcGISOnline(connection: .anonymous),
            id: PortalItem.ID("8916d50c44c746c1aafae001552bad23")!
        )
        return Map(item: portalItem)
    }()
    
    /// The power plants feature layer for querying.
    private var layer: FeatureLayer? {
        map.operationalLayers.first as? FeatureLayer
    }
    
    /// The screen point to perform an identify operation.
    @State private var identifyScreenPoint: CGPoint?
    
    /// The popup to be shown as the result of the layer identify operation.
    @State private var popup: Popup?
    
    /// A Boolean value specifying whether the popup view should be shown or not.
    @State private var showsPopup = false
    
    /// A Boolean value specifying whether the layer's feature reduction is shown.
    @State private var showsFeatureReduction = true
    
    /// A Boolean value indicating whether to show an error alert.
    @State private var isShowingAlert = false
    
    /// The error shown in the error alert.
    @State var error: Error? {
        didSet { isShowingAlert = error != nil }
    }
    
    var body: some View {
        MapViewReader { proxy in
            MapView(map: map)
                .onSingleTapGesture { screenPoint, _ in
                    identifyScreenPoint = screenPoint
                }
                .task(id: identifyScreenPoint) {
                    guard let identifyScreenPoint,
                          let layer,
                          let identifyResult = try? await proxy.identify(
                            on: layer,
                            screenPoint: identifyScreenPoint,
                            tolerance: 3
                          ),
                          let firstPopup = identifyResult.popups.first
                    else { return }
                    self.popup = firstPopup
                    self.showsPopup = true
                }
                .floatingPanel(
                    selectedDetent: .constant(.half),
                    horizontalAlignment: .leading,
                    isPresented: $showsPopup
                ) {
                    Group {
                        if let popup = popup {
                            PopupView(popup: popup, isPresented: $showsPopup)
                                .showCloseButton(true)
                        }
                    }
                    .padding()
                }
                .toolbar {
                    ToolbarItem(placement: .bottomBar) {
                        Toggle("Feature clustering", isOn: $showsFeatureReduction)
                            .toggleStyle(.switch)
                            .onChange(of: showsFeatureReduction) { isEnabled in
                                layer?.featureReduction?.isEnabled = isEnabled
                            }
                    }
                }
                .task {
                    do {
                        try await map.load()
                        layer?.featureReduction?.isEnabled = true
                    } catch {
                        self.error = error
                    }
                }
                .alert(isPresented: $isShowingAlert, presentingError: error)
        }
    }
}
