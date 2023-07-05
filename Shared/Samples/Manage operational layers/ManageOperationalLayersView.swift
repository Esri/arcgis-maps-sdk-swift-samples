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

struct ManageOperationalLayersView: View {
    /// A map with a topographic basemap and centered on western USA.
    @State private var map = {
        let map = Map(basemapStyle: .arcGISTopographic)
        map.initialViewpoint = Viewpoint(
            center: Point(x: -133e5, y: 45e5, spatialReference: .webMercator),
            scale: 2e7
        )
        return map
    }()
    
    /// A Boolean value indicating whether to show the manage layers sheet.
    @State private var isShowingSheet = false
    
    /// A Boolean value indicating whether to show an alert.
    @State private var isShowingAlert = false
    
    /// The error shown in the alert.
    @State private var error: Error? {
        didSet { isShowingAlert = error != nil }
    }
    
    var body: some View {
        MapView(map: map)
            .task {
                do {
                    // Add layers from urls.
                    let elevationImageLayer = ArcGISMapImageLayer(url: .worldElevations)
                    try await elevationImageLayer.load()
                    
                    let censusTiledLayer = ArcGISMapImageLayer(url: .censusTiles)
                    try await censusTiledLayer.load()
                    
                    map.addOperationalLayers([elevationImageLayer, censusTiledLayer])
                } catch {
                    self.error = error
                }
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button("Manage Layers") {
                        isShowingSheet = true
                    }
                    .sheet(isPresented: $isShowingSheet, detents: [.medium], dragIndicatorVisibility: .visible) {
                        ManageLayersSheetView(map: $map)
                    }
                }
            }
            .alert(isPresented: $isShowingAlert, presentingError: error)
    }
}

struct ManageLayersSheetView: View {
    /// The map with the operational layers.
    @Binding var map: Map
    
    /// The action to dismiss the manage layers sheet.
    @Environment(\.dismiss) private var dismiss
    
    /// An array for all the layers currently on the map.
    @State private var operationalLayers: [Layer] = []
    
    /// An array for all the layers removed from the map.
    @State private var removedLayers: [Layer] = []
    
    var body: some View {
        NavigationView {
            List {
                Section(
                    header: Text("Operational Layers"),
                    footer: Text("Tap and hold on a list item to drag and reorder the layers.")
                ) {
                    ForEach(operationalLayers, id: \.id) { layer in
                        HStack {
                            Button {
                                // Remove layer from map on minus button press.
                                map.removeOperationalLayer(layer)
                                removedLayers.append(layer)
                                operationalLayers.removeAll(where: { $0.id == layer.id })
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                                    .imageScale(.large)
                            }
                            Text(layer.name)
                        }
                    }
                    .onMove { fromOffsets, toOffset in
                        // Reorder the map's operational layers on list item move.
                        operationalLayers.move(fromOffsets: fromOffsets, toOffset: toOffset)
                        map.removeAllOperationalLayers()
                        map.addOperationalLayers(operationalLayers)
                    }
                }
                
                Section(header: Text("Removed Layers")) {
                    ForEach(removedLayers, id: \.id) { layer in
                        HStack {
                            Button {
                                // Add layer to map on plus button press.
                                map.addOperationalLayer(layer)
                                operationalLayers.append(layer)
                                removedLayers.removeAll(where: { $0.id == layer.id })
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.green)
                                    .imageScale(.large)
                            }
                            Text(layer.name)
                        }
                    }
                }
            }
            .navigationTitle("Manage Layers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            operationalLayers = map.operationalLayers
        }
    }
}

private extension URL {
    /// A world elevations image layer URL.
    static var worldElevations: URL {
        URL(string: "https://sampleserver5.arcgisonline.com/arcgis/rest/services/Elevation/WorldElevations/MapServer")!
    }
    
    /// A census tiled layer URL.
    static var censusTiles: URL {
        URL(string: "https://sampleserver5.arcgisonline.com/arcgis/rest/services/Census/MapServer")!
    }
}
