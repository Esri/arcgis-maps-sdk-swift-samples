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

struct DisplayContentOfUtilityNetworkContainerView: View {
    /// The display scale of this environment.
    @Environment(\.displayScale) private var displayScale
    
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// A Boolean value indicating whether the map view interaction is enabled.
    @State private var isMapViewUserInteractionEnabled = true
    
    /// A Boolean value indicating whether the legends are shown.
    @State private var isShowingLegend = false
    
    /// A Boolean value indicating whether the content within the container is shown.
    @State private var isShowingContainer = false
    
    /// The map point where the map was tapped.
    @State private var mapPoint: Point?
    
    /// The point to identify a graphic.
    @State private var screenPoint: CGPoint?
    
    /// The viewpoint before the map view zooms into the container's extent.
    @State private var previousViewpoint: Viewpoint?
    
    /// The current viewpoint of the map view.
    @State private var viewpoint = Viewpoint(latitude: 41.80, longitude: -88.16, scale: 4e3)
    
    var body: some View {
        MapViewReader { proxy in
            MapView(map: model.map, graphicsOverlays: [model.graphicsOverlay])
                .interactionModes(isMapViewUserInteractionEnabled ? .all : [])
                .onViewpointChanged(kind: .boundingGeometry) { viewpoint = $0 }
                .onSingleTapGesture { screenPoint, mapPoint in
                    self.screenPoint = screenPoint
                    self.mapPoint = mapPoint
                }
                .overlay(alignment: .top) {
                    Text(model.statusMessage)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .background(.thinMaterial, ignoresSafeAreaEdges: .horizontal)
                }
                .toolbar {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button("Show Legend") {
                            isShowingLegend = true
                        }
                        .disabled(model.legendItems.isEmpty)
                        .sheet(isPresented: $isShowingLegend, detents: [.medium]) {
                            sheetContent
                        }
                        .task(id: displayScale) {
                            // Updates the legend info when display scale changes.
                            await model.updateLegendInfoItems(displayScale: displayScale)
                        }
                        Spacer()
                        Button("Exit Container View") {
                            resetMapView(proxy)
                            model.statusMessage = "Tap on a container to see its content."
                        }
                        .disabled(!isShowingContainer)
                    }
                }
                .task {
                    // Loads the utility network.
                    do {
                        try await model.loadUtilityNetwork()
                        model.statusMessage = "Tap on a container to see its content."
                    } catch {
                        model.statusMessage = "An error occurred while loading the network."
                    }
                }
                .task(id: screenPoint) {
                    guard let screenPoint else { return }
                    // The identify results from the touch point.
                    guard let identifyResults = try? await proxy.identifyLayers(screenPoint: screenPoint, tolerance: 5) else { return }
                    // The features identified are as part of its sublayer's result.
                    guard let layerResult = identifyResults.first(where: { $0.layerContent is SubtypeFeatureLayer }) else { return }
                    // The top selected feature.
                    guard let containerFeature = (layerResult.sublayerResults
                        .lazy
                        .flatMap { $0.geoElements.compactMap { $0 as? ArcGISFeature } })
                        .first
                    else {
                        return
                    }
                    
                    do {
                        // Displays the container feature's content.
                        try await model.handleIdentifiedFeature(containerFeature)
                    } catch {
                        model.statusMessage = "An error occurred while getting the associations."
                        resetMapView(proxy)
                        return
                    }
                    
                    // Sets UI states to focus on the container's content.
                    model.setOperationalLayersVisibility(isVisible: false)
                    // Turns off user interaction to avoid straying away from the container view.
                    isMapViewUserInteractionEnabled = false
                    previousViewpoint = viewpoint
                    if let extent = model.graphicsOverlay.extent {
                        await proxy.setViewpointGeometry(extent, padding: 20)
                        isShowingContainer = true
                    }
                }
        }
    }
    
    /// A helper method to reset the map view.
    /// - Parameter proxy: The map view proxy.
    private func resetMapView(_ proxy: MapViewProxy) {
        model.setOperationalLayersVisibility(isVisible: true)
        model.graphicsOverlay.removeAllGraphics()
        isShowingContainer = false
        isMapViewUserInteractionEnabled = true
        Task {
            if let previousViewpoint {
                await proxy.setViewpoint(previousViewpoint)
            }
        }
    }
    
    /// The legends list.
    private var sheetContent: some View {
        NavigationView {
            List(model.legendItems, id: \.name) { legend in
                Label {
                    Text(legend.name)
                } icon: {
                    Image(uiImage: legend.image)
                }
            }
            .navigationTitle("Legend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isShowingLegend = false
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .frame(idealWidth: 320, idealHeight: 428)
    }
}

#Preview {
    NavigationView {
        DisplayContentOfUtilityNetworkContainerView()
    }
}
