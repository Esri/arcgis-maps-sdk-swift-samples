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

struct ApplyStyleToWMSLayerView: View {
    /// The map displayed by the map view.
    @State private var map: Map = {
        let map = Map(spatialReference: SpatialReference(wkid: .init(26915)!))
        map.minScale = 7_000_000
        return map
    }()
    /// The viewpoint of the map view.
    @State private var viewpoint: Viewpoint?
    
    /// A WMS layer with multiple styles.
    @State private var wmsSublayer: WMSSublayer?
    /// The error thrown by the WMS sublayer load operation.
    @State private var wmsSublayerLoadError: Error?
    
    /// The styles of the WMS layer.
    @State private var styles: [String] = []
    /// The current style.
    @State private var selectedStyle = ""
    
    var body: some View {
        // Display the map in a map view.
        MapView(map: map, viewpoint: viewpoint)
            .onViewpointChanged(kind: .centerAndScale) { newViewpoint in
                viewpoint = newViewpoint
            }
            .task {
                // Create the WMS layer and add it to the map.
                let wmsLayer = WMSLayer(
                    url: URL(string: "https://imageserver.gisdata.mn.gov/cgi-bin/mncomp?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetCapabilities")!,
                    layerNames: ["mncomp"]
                )
                map.addOperationalLayer(wmsLayer)
                // Load the WMS layer to get the styles.
                do {
                    try await wmsLayer.load()
                    viewpoint = wmsLayer.fullExtent.map { Viewpoint(boundingGeometry: $0) }
                    wmsSublayer = wmsLayer.sublayers.first as? WMSSublayer
                    styles = wmsLayer.layerInfos.first?.styles ?? []
                    selectedStyle = styles.first ?? ""
                } catch {
                    wmsSublayerLoadError = error
                }
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Picker("Style", selection: $selectedStyle) {
                        ForEach(styles, id: \.self) { style in
                            let title = switch style {
                            case "default": "Default"
                            case "stretch": "Contrast Stretch"
                            default: "Unknown"
                            }
                            Text(title)
                                .tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedStyle) {
                        wmsSublayer?.currentStyle = selectedStyle
                    }
                }
            }
            .errorAlert(presentingError: $wmsSublayerLoadError)
    }
}

#Preview {
    ApplyStyleToWMSLayerView()
}
