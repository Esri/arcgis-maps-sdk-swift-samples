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

struct DisplayClustersView: View {
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
    
    /// The geoelements in the selected cluster.
    @State private var geoElements: [GeoElement] = []
    
    /// The popup to be shown as the result of the layer identify operation.
    @State private var popup: Popup?
    
    /// A Boolean value specifying whether the popup view should be shown or not.
    @State private var showsPopup = false
    
    /// A Boolean value specifying whether the layer's feature reduction is shown.
    @State private var showsFeatureReduction = true
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    var body: some View {
        MapViewReader { proxy in
            MapView(map: map)
                .onSingleTapGesture { screenPoint, _ in
                    identifyScreenPoint = screenPoint
                }
                .task(id: identifyScreenPoint) {
                    layer?.clearSelection()
                    geoElements.removeAll()
                    
                    guard let identifyScreenPoint,
                          let layer,
                          let identifyResult = try? await proxy.identify(
                            on: layer,
                            screenPoint: identifyScreenPoint,
                            tolerance: 3
                          )
                    else { return }
                    self.popup = identifyResult.popups.first
                    self.showsPopup = self.popup != nil
                    
                    guard let identifyGeoElement = identifyResult.geoElements.first else { return }
                    if let aggregateGeoElement = identifyGeoElement as? AggregateGeoElement {
                        aggregateGeoElement.isSelected = true
                        let geoElements = try? await aggregateGeoElement.geoElements
                        self.geoElements = geoElements ?? []
                    } else if let feature = identifyGeoElement as? Feature {
                        layer.selectFeature(feature)
                    }
                }
                .floatingPanel(
                    selectedDetent: .constant(.half),
                    horizontalAlignment: .leading,
                    isPresented: $showsPopup
                ) { [popup] in
                    PopupView(popup: popup!, isPresented: $showsPopup)
                        .showCloseButton(true)
                        .padding([.top, .horizontal])
                    
                    if !geoElements.isEmpty {
                        List {
                            Section {
                                ForEach(Array(geoElements.enumerated()),
                                        id: \.offset
                                ) { offset, geoElement in
                                    let name = geoElement.attributes["name"] as? String
                                    Text(name ?? "Geoelement: \(offset)")
                                }
                            } header: {
                                Text("Geoelements")
                                    .font(.title3)
                                    .bold()
                                    .foregroundColor(.primary)
                            }
                        }
                        .listStyle(.inset)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .bottomBar) {
                        Toggle(
                            showsFeatureReduction ? "Feature Clustering Enabled" : "Feature Clustering Disabled",
                            isOn: $showsFeatureReduction
                        )
                        .onChange(of: showsFeatureReduction) { isEnabled in
                            layer?.featureReduction?.isEnabled = isEnabled
                        }
                    }
                }
                .task {
                    do {
                        try await map.load()
                        await proxy.setViewpointScale(1e7)
                        layer?.featureReduction?.isEnabled = true
                    } catch {
                        self.error = error
                    }
                }
                .errorAlert(presentingError: $error)
        }
    }
}

#Preview {
    NavigationView {
        DisplayClustersView()
    }
}
