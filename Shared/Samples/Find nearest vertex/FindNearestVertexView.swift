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

struct FindNearestVertexView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    var body: some View {
        // Create a map view to display the map.
        MapView(map: model.map)
            .onSingleTapGesture { _, mapPoint in
            }
    }
}

private extension FindNearestVertexView {
    // The view model for this sample.
    private class Model: ObservableObject {
        /// The spatial reference for the sample.
        let statePlaneCaliforniaZone5: SpatialReference
        
        /// A map with a topographic basemap.
        var map: Map = Map()
        
        
        init() {
            statePlaneCaliforniaZone5 = SpatialReference(wkid: WKID(2229)!)!
            
            map = {
                let map = Map(spatialReference: statePlaneCaliforniaZone5)
                let usStatesGeneralizedLayer = FeatureLayer(
                    item: PortalItem(
                        portal: .arcGISOnline(connection: .anonymous),
                        id: Item.ID(rawValue: "99fd67933e754a1181cc755146be21ca")!))
                map.basemap.baseLayers.add(usStatesGeneralizedLayer)
                return map
            }()
            
        }
    }
}
