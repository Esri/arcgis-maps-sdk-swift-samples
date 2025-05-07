// Copyright 2025 Esri
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

struct ApplySimpleRendererToFeatureLayerView: View {
    @State private var map: Map = {
        let map = Map(basemapStyle: .arcGISTopographic)
        let featureLayer = FeatureLayer(
            item: PortalItem(
                portal: .arcGISOnline(connection: .anonymous),
                id: PortalItem.ID("6d41340931544829acc8f68c27e69dec")!
            )
        )
        map.addOperationalLayer(featureLayer)
        map.initialViewpoint = Viewpoint(latitude: 35.61, longitude: -82.44, scale: 1e4)
        return map
    }()
    
    /// The feature layer in the map.
    private var featureLayer: FeatureLayer {
        map.operationalLayers.first as! FeatureLayer
    }
    
    var body: some View {
        MapView(map: map)
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button("Change Renderer") {
                        setRenderer()
                    }
                }
            }
    }
    
    /// Sets the renderer for the feature layer.
    private func setRenderer() {
        // Creates a simple marker symbol for the renderer.
        let symbol = SimpleMarkerSymbol(
            style: .circle,
            color: [UIColor.red, .yellow, .blue, .green].randomElement()!,
            size: 10
        )
        // Creates a new renderer using the symbol just created.
        let renderer = SimpleRenderer(symbol: symbol)
        // Assigns the new renderer to the feature layer.
        featureLayer.renderer = renderer
    }
}

#Preview {
    ApplySimpleRendererToFeatureLayerView()
}
