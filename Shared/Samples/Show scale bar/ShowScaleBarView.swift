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
import ArcGISToolkit
import SwiftUI

struct ShowScaleBarView: View {
    /// The height of the map view's attribution bar.
    @State private var attributionBarHeight = 0.0
    
    /// The spatial reference specifies how geometry coordinates relate to real-world space.
    /// This property allows for communication between the `Scalebar` and `MapView`.
    @State private var spatialReference: SpatialReference?
    
    /// Allows for communication between the `Scalebar` and `MapView`.
    @State private var unitsPerPoint: Double?
    
    /// The maximum screen width allotted to the scalebar.
    private let maxWidth: Double = 175.0
    
    /// Allows for communication between the `Scalebar` and `MapView`.
    @State private var viewpoint: Viewpoint?
    
    /// The location of the scalebar on screen.
    private let alignment: Alignment = .bottomLeading
    
    /// A map with a topographic style.
    @State private var map: Map = {
        let map = Map(basemapStyle: .arcGISTopographic)
        // Creates an initial Viewpoint with a coordinate point
        // centered on San Franscisco's Golden Gate Bridge.
        map.initialViewpoint = Viewpoint(
            center: Point(x: -13637000, y: 4550000, spatialReference: .webMercator),
            scale: 100_000
        )
        return map
    }()
    
    // The ScalebarSettings add the shadow to the scale bar.
    @State private var scaleBarSettings: ScalebarSettings = {
        let settings = ScalebarSettings(
            shadowColor: Color.black,
            shadowRadius: 4
        )
        return settings
    }()
    
    var body: some View {
        MapView(map: map).onAttributionBarHeightChanged { newHeight in
            withAnimation { attributionBarHeight = newHeight }
        }
        .onSpatialReferenceChanged { spatialReference = $0 }
        .onUnitsPerPointChanged { unitsPerPoint = $0 }
        .onViewpointChanged(kind: .centerAndScale) { viewpoint = $0 }
        .overlay(alignment: alignment) {
            Scalebar(
                maxWidth: maxWidth,
                settings: scaleBarSettings,
                spatialReference: spatialReference,
                style: .graduatedLine,
                unitsPerPoint: unitsPerPoint,
                viewpoint: viewpoint
            )
            // The styling around scale bar.
            .padding(.leading, 40)
            .padding(.trailing, 50)
            .padding(.vertical, 10)
            .background(Color.white)
            .opacity(0.8)
            .cornerRadius(8)
            .padding(.vertical, 10 + attributionBarHeight)
        }
    }
}

#Preview {
    ShowScaleBarView()
}
