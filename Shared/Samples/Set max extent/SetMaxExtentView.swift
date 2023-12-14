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

struct SetMaxExtentView: View {
    /// A graphics overlay to show the extent envelope graphic.
    @State private var graphicsOverlay: GraphicsOverlay = {
        let envelopeSymbol = SimpleLineSymbol(
            style: .dash,
            color: .red,
            width: 5
        )
        let envelopeGraphic = Graphic(
            geometry: Envelope.coloradoExtent,
            symbol: envelopeSymbol
        )
        return GraphicsOverlay(graphics: [envelopeGraphic])
    }()
    
    /// A map with streets basemap.
    @State private var map: Map = {
        let map = Map(basemapStyle: .arcGISStreets)
        // Set the map's max extent to an envelope of Colorado's northwest and southeast corners.
        map.maxExtent = .coloradoExtent
        return map
    }()
    
    /// A Boolean value indicating whether the max extent is set.
    @State private var maxExtentIsSet = true
    
    var body: some View {
        MapView(map: map, graphicsOverlays: [graphicsOverlay])
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Toggle(maxExtentIsSet ? "Max Extent Enabled" : "Max Extent Disabled", isOn: $maxExtentIsSet)
                        .onChange(of: maxExtentIsSet) { newValue in
                            if newValue {
                                // Set the map's max extent to limit the map view to a certain
                                // visible area.
                                map.maxExtent = .coloradoExtent
                            } else {
                                // Set the map's max extent to nil so it doesn't limit panning or
                                // zooming.
                                map.maxExtent = nil
                            }
                        }
                }
            }
    }
}

private extension Envelope {
    /// An envelope of the boundaries of Colorado.
    static var coloradoExtent: Envelope {
        Envelope(
            xMin: -12139393.2109,
            yMin: 4438148.7816,
            xMax: -11359277.5124,
            yMax: 5012444.0468
        )
    }
}

#Preview {
    NavigationView {
        SetMaxExtentView()
    }
}
