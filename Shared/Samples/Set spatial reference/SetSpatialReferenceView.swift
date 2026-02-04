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

struct SetSpatialReferenceView: View {
    /// A map with spatial reference and a basemap.
    @State private var map: Map = {
        let map = Map(spatialReference: .worldBonne)
        map.basemap = Basemap(
            baseLayer: ArcGISMapImageLayer(url: .worldCities)
        )
        return map
    }()
    /// The currently selected spatial reference.
    @State private var selectedSpatialReference: SpatialReference = .worldBonne
    
    var body: some View {
        MapView(map: map)
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Menu("Set Spatial Reference") {
                        Picker("Spatial Reference", selection: $selectedSpatialReference) {
                            ForEach(SpatialReference.allOptions, id: \.wkid) { spatialReference in
                                Text(spatialReference.name)
                                    .tag(spatialReference)
                            }
                        }
                        .onChange(of: selectedSpatialReference) {
                            map.setSpatialReference(selectedSpatialReference)
                        }
                    }
                }
            }
    }
}

private extension URL {
    /// The URL to the World Cities map service for the map image layer.
    static var worldCities: URL {
        URL(string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/SampleWorldCities/MapServer")!
    }
}

// MARK: - Spatial References

private extension SpatialReference {
    /// A human-readable name for the spatial reference.
    var name: String {
        if self == .berghausStar {
            return "Berghaus Star AAG"
        } else if self == .fuller {
            return "Fuller"
        } else if self == .newZealandMapGrid {
            return "New Zealand Map Grid"
        } else if self == .northPoleStereographic {
            return "North Pole Stereographic"
        } else if self == .peirceQuincuncial {
            return "Peirce Quincuncial"
        } else if self == .utmZone10N {
            return "UTM Zone 10 N"
        } else if self == .worldBonne {
            return "World Bonne"
        } else if self == .worldOrthographic {
            return "World Orthographic"
        } else if self == .worldGoodeHomolosine {
            return "World Goode Homolosine"
        } else if self == .webMercator {
            return "Web Mercator"
        } else if self == .wgs84 {
            return "WGS 84"
        } else {
            return "Unknown"
        }
    }
    
    /// Berghaus Star AAG (WKID: 102299).
    static var berghausStar: SpatialReference {
        SpatialReference(wkid: WKID(102299)!)!
    }
    /// Fuller (WKID: 54050).
    static var fuller: SpatialReference {
        SpatialReference(wkid: WKID(54050)!)!
    }
    /// New Zealand Map Grid (WKID: 27200).
    static var newZealandMapGrid: SpatialReference {
        SpatialReference(wkid: WKID(27200)!)!
    }
    /// North Pole Stereographic (WKID: 102018).
    static var northPoleStereographic: SpatialReference {
        SpatialReference(wkid: WKID(102018)!)!
    }
    /// Peirce quincuncial North Pole in a square (WKID: 54090).
    static var peirceQuincuncial: SpatialReference {
        SpatialReference(wkid: WKID(54090)!)!
    }
    /// UTM Zone 10 N (WKID: 32610).
    static var utmZone10N: SpatialReference {
        SpatialReference(wkid: WKID(32610)!)!
    }
    /// World Bonne (WKID: 54024).
    static var worldBonne: SpatialReference {
        SpatialReference(wkid: WKID(54024)!)!
    }
    /// World Goode Homolosine Land (WKID: 54052).
    static var worldGoodeHomolosine: SpatialReference {
        SpatialReference(wkid: WKID(54052)!)!
    }
    /// Orthographic projection of the World from Space (WKID: 102038).
    static var worldOrthographic: SpatialReference {
        SpatialReference(wkid: WKID(102038)!)!
    }
    
    /// All available spatial references for selection.
    static var allOptions: [SpatialReference] {
        return [
            .berghausStar,
            .fuller,
            .newZealandMapGrid,
            .northPoleStereographic,
            .peirceQuincuncial,
            .utmZone10N,
            .worldBonne,
            .worldGoodeHomolosine,
            .worldOrthographic,
            .webMercator,
            .wgs84
        ]
    }
}

#Preview {
    SetSpatialReferenceView()
}
