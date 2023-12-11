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
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
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
                        ManageLayersSheetView(map: map)
                    }
                }
            }
            .errorAlert(presentingError: $error)
    }
}

struct ManageLayersSheetView: View {
    /// The map with the operational layers.
    let map: Map
    
    /// The action to dismiss the manage layers sheet.
    @Environment(\.dismiss) private var dismiss
    
    /// An array for all the layers currently on the map.
    @State private var operationalLayers: [Layer] = []
    
    /// An array for all the layers removed from the map.
    @State private var removedLayers: [Layer] = []
    
    var body: some View {
        VStack {
            ZStack {
                Text("Manage Layers")
                    .bold()
                HStack {
                    Spacer()
                    EditButton()
                }
            }
            .padding([.top, .leading, .trailing])

            List {
                Section {
                    ForEach(operationalLayers, id: \.id) { layer in
                        HStack {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                                .imageScale(.large)
                                .clipped()
                                .onTapGesture {
                                    // Remove layer from map on minus press.
                                    map.removeOperationalLayer(layer)
                                    removedLayers.append(layer)
                                    operationalLayers.removeAll(where: { $0.id == layer.id })
                                }
                            Text(layer.name)
                        }
                    }
                    .onMove { fromOffsets, toOffset in
                        // Reorder the map's operational layers on list row move.
                        operationalLayers.move(fromOffsets: fromOffsets, toOffset: toOffset)
                        map.removeAllOperationalLayers()
                        map.addOperationalLayers(operationalLayers)
                    }
                } header: {
                    Text("Operational Layers")
                        #if targetEnvironment(macCatalyst)
                        .padding(.top)
                        #endif
                } footer: {
                    Text("Tap \"Edit\" to reorder the layers.")
                }
                
                Section {
                    ForEach(removedLayers, id: \.id) { layer in
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                                .imageScale(.large)
                                .clipped()
                                .onTapGesture {
                                    // Add layer to map on plus press.
                                    map.addOperationalLayer(layer)
                                    operationalLayers.append(layer)
                                    removedLayers.removeAll(where: { $0.id == layer.id })
                                }
                            Text(layer.name)
                        }
                    }
                } header: {
                    Text("Removed Layers")
                }
            }
        }
        .background(Color(.systemGroupedBackground))
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

#Preview {
    NavigationView {
        ManageOperationalLayersView()
    }
}
