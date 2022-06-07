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

struct ShowCalloutView: View {
    /// A map with a topographic basemap style.
    @StateObject private var map = Map(basemapStyle: .arcGISTopographic)
    
    /// A location callout placement.
    @State private var calloutPlacement: LocationCalloutPlacement?
    
    var body: some View {
        MapView(map: map)
            .onSingleTapGesture { _, mapPoint in
                // Projects the point to WGS 84 spatial reference.
                let location = GeometryEngine.project(mapPoint, into: .wgs84)!
                
                // Sets the callout placement location to the tap location
                // if callout placement is nil.
                // If not nil, sets the callout placement to nil.
                calloutPlacement = calloutPlacement == nil ? LocationCalloutPlacement(
                    location: location,
                    offset: .zero,
                    allowsOffsetRotation: false
                ) : nil
            }
            .callout(placement: $calloutPlacement.animation()) { callout in
                VStack(alignment: .leading) {
                    Text("Location")
                        .font(.headline)
                    Text("x: \(String(format: "%.2f", callout.location.x)), y: \(String(format: "%.2f", callout.location.y))")
                        .font(.callout)
                }
                .padding(5)
            }
    }
}
