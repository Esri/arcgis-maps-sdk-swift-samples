// Copyright 2022 Esri
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
import ArcGISToolkit

struct SetBasemapView: View {
    /// A map with imagery basemap.
    @StateObject private var map = Map(basemapStyle: .arcGISImagery)
    
    /// The initial viewpoint of the map.
    private let initialViewpoint = Viewpoint(
        center: Point(x: -118.4, y: 33.7, spatialReference: .wgs84),
        scale: 1e6
    )
    
    /// A Boolean value that indicates whether to show the basemap gallery.
    @State private var showBasemapGallery = false
    
    var body: some View {
        MapView(map: map, viewpoint: initialViewpoint)
            .overlay(alignment: .topTrailing) {
                if showBasemapGallery {
                    BasemapGallery(geoModel: map)
                        .style(.automatic())
                        .esriBorder()
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Toggle(isOn: $showBasemapGallery) {
                        Label("Show base map", systemImage: "map")
                    }
                }
            }
    }
}
