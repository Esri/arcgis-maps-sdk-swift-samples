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
    
    /// An array for every layer on the map or that could be added to the map.
    @State private var allLayers: [Layer] = []
    
    /// The layers present in all layers but not in the map's operational Layers.
    private var removedLayers: [Layer] {
        allLayers.filter { layer in
            !map.operationalLayers.contains(where: { $0.name == layer.name })
        }
    }
    
    /// A Boolean value
    @State private var isShowingOptions = false
    
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
                    
                    allLayers = [elevationImageLayer, censusTiledLayer]
                    map.addOperationalLayers(allLayers)
                } catch {
                    self.error = error
                }
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button("Manage Layers") {
                        isShowingOptions.toggle()
                    }
                }
            }
            .sheet(isPresented: $isShowingOptions, detents: [.medium], dragIndicatorVisibility: .visible) {
                List {
                    Section(header: Text("Operational Layers")) {
                        ForEach(map.operationalLayers, id: \.name) { layer in
                            Text(layer.name)
                        }
                        .onMove {
                            allLayers.move(fromOffsets: $0, toOffset: $1)
                            map.removeAllOperationalLayers()
                            map.addOperationalLayers(allLayers)
                        }
                    }
                    Section(header: Text("Removed Layers")) {
                        ForEach(removedLayers, id: \.name) { layer in
                            Text(layer.name)
                        }
                    }
                }
            }
            .alert(isPresented: $isShowingAlert, presentingError: error)
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
