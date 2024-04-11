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
    @State private var map = Map(basemapStyle: .arcGISTopographic)
    
    /// A location callout placement.
    @State private var calloutPlacement: CalloutPlacement?
    
    /// The tap location.
    @State private var tapLocation: Point!
    
    var body: some View {
        MapView(map: map)
            .onSingleTapGesture { _, mapPoint in
                tapLocation = mapPoint
                if calloutPlacement == nil {
                    // Projects the point to the WGS 84 spatial reference.
                    let location = GeometryEngine.project(mapPoint, into: .wgs84)!
                    // Shows the callout at the tapped location.
                    calloutPlacement = CalloutPlacement.location(location)
                } else {
                    // Hides the callout.
                    calloutPlacement = nil
                }
            }
            .callout(placement: $calloutPlacement.animation(.default.speed(2))) { _ in
                VStack(alignment: .leading) {
                    Text("Location")
                        .font(.headline)
                    Text(
                        CoordinateFormatter.latitudeLongitudeString(
                            from: tapLocation,
                            format: .decimalDegrees,
                            decimalPlaces: 2
                        )
                    )
                    .font(.callout)
                }
                .padding(5)
            }
    }
}

#Preview {
    ShowCalloutView()
}
