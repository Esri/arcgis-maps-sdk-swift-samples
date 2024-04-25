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

struct MonitorChangesToLayerViewStateView: View {
    /// A map with a topographic basemap.
    @State private var map: Map = {
        let map = Map(basemapStyle: .arcGISTopographic)
        map.initialViewpoint = Viewpoint(
            center: Point(x: -13e6, y: 51e5, spatialReference: .webMercator),
            scale: 2e7
        )
        return map
    }()
    
    /// The Satellite (MODIS) Thermal Hotspots and Fire Activity feature layer.
    @State private var featureLayer: FeatureLayer = {
        let portalItem = PortalItem(url: .thermalHotspotsAndFireActivity)!
        let featureLayer = FeatureLayer(item: portalItem)
        
        featureLayer.minScale = 1e8
        featureLayer.maxScale = 6e6
        
        return featureLayer
    }()
    
    /// The text representing the view status of the feature layer.
    @State private var statusText = ""
    
    /// A Boolean value indicating whether the feature layer is visible.
    @State private var layerIsVisible = true
    
    var body: some View {
        MapView(map: map)
            .onLayerViewStateChanged { layer, layerViewState in
                // Only checks the view state of the feature layer.
                guard layer.id == featureLayer.id else { return }
                
                // Gets the status from the view state for the layer.
                statusText = layerViewState.status.label
            }
            .overlay(alignment: .top) {
                Text("Layer view status:\n\(statusText)")
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(8)
                    .background(.regularMaterial, ignoresSafeAreaEdges: .horizontal)
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Toggle(
                        layerIsVisible ? "Layer Enabled" : "Layer Disabled",
                        isOn: $layerIsVisible
                    )
                    .onChange(of: layerIsVisible) { newValue in
                        featureLayer.isVisible = newValue
                    }
                }
            }
            .onAppear {
                // Adds the feature layer to the map.
                map.addOperationalLayer(featureLayer)
            }
    }
}

private extension LayerViewState.Status {
    /// A human-readable label for the status.
    var label: String {
        var statuses: [String] = []
        if self.contains(.active) {
            statuses.append("Active")
        }
        if self.contains(.notVisible) {
            statuses.append("Not Visible")
        }
        if self.contains(.outOfScale) {
            statuses.append("Out of Scale")
        }
        if self.contains(.loading) {
            statuses.append("Loading")
        }
        if self.contains(.error) {
            statuses.append("Error")
        }
        if self.contains(.warning) {
            statuses.append("Warning")
        }
        
        if !statuses.isEmpty {
            return statuses.joined(separator: ", ")
        } else {
            return "Unknown"
        }
    }
}

private extension URL {
    /// The URL for the Satellite (MODIS) Thermal Hotspots and Fire Activity portal item.
    static var thermalHotspotsAndFireActivity: URL {
        URL(string: "https://runtime.maps.arcgis.com/home/item.html?id=b8f4033069f141729ffb298b7418b653")!
    }
}

#Preview {
    NavigationStack {
        MonitorChangesToLayerViewStateView()
    }
}
