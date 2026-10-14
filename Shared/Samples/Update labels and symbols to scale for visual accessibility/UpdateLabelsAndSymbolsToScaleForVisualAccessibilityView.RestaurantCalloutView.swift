// Copyright 2026 Esri
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

extension UpdateLabelsAndSymbolsToScaleForVisualAccessibilityView {
    /// The selected restaurant's name and WGS 84 coordinates.
    struct RestaurantCalloutView: View {
        /// The selected restaurant.
        let feature: Feature

        /// The map height available above the bottom controls.
        let mapHeight: CGFloat

        /// The callout's content height before any scrolling is needed.
        @State private var calloutContentHeight: CGFloat?

        var body: some View {
            let name = (feature.attributes["name"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let location = (feature.geometry as? Point).flatMap {
                GeometryEngine.project($0, into: .wgs84)
            }
            let coordinateFormat = FloatingPointFormatStyle<Double>.number
                .precision(.fractionLength(5))

            ScrollView {
                VStack(alignment: .leading) {
                    Text(name.flatMap { $0.isEmpty ? nil : $0 } ?? "Restaurant")
                        .font(.headline)
                    if let location {
                        Text("Latitude: \(location.y, format: coordinateFormat)")
                        Text("Longitude: \(location.x, format: coordinateFormat)")
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding()
                .onGeometryChange(for: CGFloat.self) { geometry in
                    geometry.size.height
                } action: { height in
                    calloutContentHeight = height
                }
            }
            // Let the callout container propose a smaller scrolling viewport.
            .frame(maxHeight: min(calloutContentHeight ?? mapHeight, mapHeight))
        }
    }
}
