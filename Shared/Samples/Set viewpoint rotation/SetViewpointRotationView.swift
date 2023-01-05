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
    /// The center of the viewpoint.
    @State private var center = Point(x: -117.156229, y: 32.713652, spatialReference: .wgs84)
    
    /// The scale of the viewpoint.
    @State private var scale = 5e4
    
    /// The rotation angle for the viewpoint.
    @State private var rotation = Double.zero
    
    private class Model: ObservableObject {
        /// A map with ArcGIS Streets basemap style.
        let map: Map = Map(basemapStyle: .arcGISStreets)
    }
    
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    var body: some View {
        VStack {
            MapView(map: model.map, viewpoint: Viewpoint(center: center, scale: scale, rotation: rotation))
                .onViewpointChanged(kind: .centerAndScale) { viewpoint in
                    center = viewpoint.targetGeometry.extent.center
                    scale = viewpoint.targetScale
                    rotation = viewpoint.rotation
                }
                .overlay(alignment: .topTrailing) {
                    Compass(
                        viewpointRotation: $rotation,
                        autoHide: false
                    )
                    .padding()
                }
            
            HStack {
                // Create a slider to rotate the map.
                Slider(value: $rotation, in: 0...359)
                
                Text(
                    Measurement(
                        value: rotation,
                        unit: UnitAngle.degrees
                    ),
                    format: .measurement(
                        width: .narrow,
                        numberFormatStyle: .number.precision(.fractionLength(0))
                    )
                )
                .frame(minWidth: 60, alignment: .leading)
            }
            .padding(.horizontal, 50)
            .frame(maxWidth: 540)
        }
        .padding(.bottom)
    }
}
