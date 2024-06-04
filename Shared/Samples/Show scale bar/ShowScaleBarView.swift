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

struct ShowScaleBarView: View {
    @State private var attributionBarHeight = 0.0
    
    /// Allows for communication between the `Scalebar` and `MapView`.
    @State private var spatialReference: SpatialReference?
    
    /// Allows for communication between the `Scalebar` and `MapView`.
    @State private var unitsPerPoint: Double?
    
    /// The maximum screen width allotted to the scalebar.
    private let maxWidth: Double = 175.0
    /// Allows for communication between the `Scalebar` and `MapView`.
    @State private var viewpoint: Viewpoint?
    /// The location of the scalebar on screen.
    private let alignment: Alignment = .bottomLeading
    
    @State private var map: Map = {
        let map = Map(basemapStyle: .arcGISDarkGrayBase)
        return map
    }()
    
    
    var body: some View {
        MapViewReader { mapViewProxy in
            MapView(map: map).onAttributionBarHeightChanged { newHeight in
                withAnimation { attributionBarHeight = newHeight }
            }
            .onSpatialReferenceChanged { spatialReference = $0 }
            .onUnitsPerPointChanged { unitsPerPoint = $0 }
            .onViewpointChanged(kind: .centerAndScale) { viewpoint = $0 }
            .overlay(alignment: alignment) {
                Scalebar(
                    maxWidth: maxWidth,
                    spatialReference: spatialReference,
                    unitsPerPoint: unitsPerPoint,
                    viewpoint: viewpoint
                )
                .padding(.horizontal, 10)
                .padding(.vertical, 10 + attributionBarHeight)
            }
        }
    }
}

#Preview {
    ShowScaleBarView()
}
