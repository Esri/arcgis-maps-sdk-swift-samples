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
    /// A Boolean value that indicates whether to show the basemap gallery.
    @State private var isShowingBasemapGallery = false
    
    /// The model used to store the geo model and other expensive objects
    /// used in this view.
    private class Model: ObservableObject {
        /// A map with imagery basemap.
        let map: Map = {
            let map = Map(basemapStyle: .arcGISImagery)
            // The initial viewpoint of the map.
            map.initialViewpoint = Viewpoint(
                center: Point(x: -118.4, y: 33.7, spatialReference: .wgs84),
                scale: 1e6
            )
            return map
        }()
    }
    
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    var body: some View {
        MapView(map: model.map)
            .overlay(alignment: .topTrailing) {
                if isShowingBasemapGallery {
                    BasemapGallery(geoModel: model.map)
                        .style(.automatic())
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Toggle(isOn: $isShowingBasemapGallery) {
                        Label("Show base map", systemImage: "map")
                    }
                }
            }
    }
}
