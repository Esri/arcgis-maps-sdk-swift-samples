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

struct ManageOperationalLayersView: View {
    /// A map with a topographic basemap centered on western USA.
    @State private var map: Map = {
        let map = Map(basemapStyle: .arcGISTopographic)
        map.initialViewpoint = Viewpoint(
            center: Point(x: -133e5, y: 45e5, spatialReference: .webMercator),
            scale: 2e7
        )
        return map
    }()
    
    /// The operational layers for the sample.
    @State private var operationalLayers: [Layer] = [
        ArcGISMapImageLayer(url: .worldElevations),
        ArcGISMapImageLayer(url: .censusTiles)
    ]
    
    /// A Boolean value indicating whether the manage layers view is presented.
    @State private var manageLayersIsPresented = false
    
    var body: some View {
        MapView(map: map)
            .task {
                // Loads and adds the operational layers to the map.
                await operationalLayers.load()
                map.addOperationalLayers(operationalLayers)
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button("Manage Layers") {
                        manageLayersIsPresented = true
                    }
                    .popover(isPresented: $manageLayersIsPresented) {
                        NavigationStack {
                            ManageLayersView(map: map, layers: operationalLayers)
                                .navigationTitle("Manage Layers")
                                .navigationBarTitleDisplayMode(.inline)
                                .toolbar {
                                    ToolbarItem(placement: .confirmationAction) {
                                        Button("Done") { manageLayersIsPresented = false }
                                    }
                                }
                        }
                        .presentationDetents([.fraction(0.5)])
                        .frame(idealWidth: 320, idealHeight: 360)
                    }
                }
            }
    }
}

/// A view for managing the layers of a given map.
private struct ManageLayersView: View {
    /// The map to manage.
    let map: Map
    
    /// The layers to add to and remove from the map.
    let layers: [Layer]
    
    /// The layers currently added to the map.
    @State private var operationalLayers: [Layer] = []
    
    /// The layers removed from the map.
    @State private var removedLayers: [Layer] = []
    
    var body: some View {
        Form {
            Section {
                ForEach(operationalLayers, id: \.id) { layer in
                    HStack {
                        Button("Remove Layer", systemImage: "minus.circle.fill") {
                            map.removeOperationalLayer(layer)
                            
                            withAnimation {
                                operationalLayers.removeAll { $0.id == layer.id }
                                removedLayers.append(layer)
                            }
                        }
                        .foregroundStyle(.red)
                        
                        Text(layer.name)
                    }
                }
            } header: {
                HStack {
                    Text("Operational Layers")
                    Spacer()
                    Button("Swap Layers", systemImage: "arrow.up.arrow.down.circle") {
                        let layer = operationalLayers.first!
                        map.removeOperationalLayer(layer)
                        map.addOperationalLayer(layer)
                        
                        withAnimation {
                            operationalLayers.reverse()
                        }
                    }
                    .disabled(operationalLayers.count < 2)
                }
            }
            
            Section("Removed Layers") {
                ForEach(removedLayers, id: \.id) { layer in
                    HStack {
                        Button("Add Layer", systemImage: "plus.circle.fill") {
                            map.addOperationalLayer(layer)
                            
                            withAnimation {
                                removedLayers.removeAll { $0.id == layer.id }
                                operationalLayers.append(layer)
                            }
                        }
                        .foregroundStyle(.green)
                        
                        Text(layer.name)
                    }
                }
            }
        }
        .labelStyle(.iconOnly)
        .onAppear {
            operationalLayers = map.operationalLayers
            removedLayers = layers.filter { layer in
                !operationalLayers.contains { $0.id == layer.id }
            }
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
    NavigationStack {
        ManageOperationalLayersView()
    }
}
