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

struct DisplayOverviewMapView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// The current viewpoint of the map view.
    @State private var viewpoint = Viewpoint(
        center: Point(x: -123.12052, y: 49.28299, spatialReference: .wgs84),
        scale: 1e5
    )
    
    /// The visible area marked with a red rectangle on the overview map.
    @State private var visibleArea: ArcGIS.Polygon?
    
    var body: some View {
        MapView(map: model.map, viewpoint: viewpoint)
            .onViewpointChanged(kind: .centerAndScale) { viewpoint = $0 }
            .onVisibleAreaChanged { visibleArea = $0 }
            .overlay(alignment: .topTrailing) {
                OverviewMap.forMapView(
                    with: viewpoint,
                    visibleArea: visibleArea
                )
                .frame(width: 200, height: 132)
                .padding()
            }
    }
}

private extension DisplayOverviewMapView {
    /// The model used to store the geo model and other expensive objects
    /// used in this view.
    class Model: ObservableObject {
        /// A map with imagery basemap and a tourist attraction feature layer.
        let map: Map = {
            let featureLayer = FeatureLayer(
                item: PortalItem(
                    portal: .arcGISOnline(connection: .anonymous),
                    id: .northAmericaTouristAttractions
                )
            )
            let map = Map(basemapStyle: .arcGISTopographic)
            map.addOperationalLayer(featureLayer)
            return map
        }()
    }
}

private extension PortalItem.ID {
    static var northAmericaTouristAttractions: Self { Self("97ceed5cfc984b4399e23888f6252856")! }
}
