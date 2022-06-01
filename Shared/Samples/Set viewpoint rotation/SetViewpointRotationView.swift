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

struct SetViewpointRotationView: View {
    /// A map with ArcGIS Streets basemap style.
    @StateObject private var map = Map(basemapStyle: .arcGISStreets)
    
    /// An optional-type viewpoint with starting rotation degree of zero.
    @State private var viewpoint: Viewpoint! = Viewpoint(
        center: Point(x: -117.156229, y: 32.713652, spatialReference: .wgs84),
        scale: 50_000,
        rotation: 0
    )
    
    var body: some View {
        VStack {
            MapView(map: map, viewpoint: viewpoint)
                .onViewpointChanged(kind: .centerAndScale) { viewpoint = $0 }
                .overlay(alignment: .topTrailing) {
                    Compass(
                        viewpoint: $viewpoint,
                        autoHide: false
                    )
                        .frame(width: 44, height: 44)
                        .padding()
                }
            
            HStack {
                // Create a slider to rotate the map.
                Slider(
                    value: Binding(get: {
                        viewpoint.rotation
                    }, set: { degree in
                        // Update the viewpoint with new, rotated viewpoint.
                        let rotationViewpoint = Viewpoint(
                            center: viewpoint.targetGeometry as! Point,
                            scale: viewpoint.targetScale,
                            rotation: degree
                        )
                        viewpoint = rotationViewpoint
                    }),
                    in: 0...360
                )
                
                Text(String(format: "%.0f˚", viewpoint.rotation))
                    .frame(width: 40, alignment: .leading)
            }
            .padding(.horizontal, 50)
        }
    }
}
