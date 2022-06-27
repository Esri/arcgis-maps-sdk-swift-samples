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

import ArcGIS
import SwiftUI

struct ClipGeometryView: View {
    /// A Boolean value indicating whether to disable the clip button.
    @State private var clipIsDisabled = false
    
    /// A map with an initial viewpoint of Colorado.
    @StateObject private var map: Map = {
        let map = Map(basemapStyle: .arcGISTopographic)
        // Sets the initial viewpoint to Colorado and adds additional padding.
        map.initialViewpoint = Viewpoint(targetExtent: .coloradoEnvelope.expanded(by: 2))
        return map
    }()
    
    /// The graphics overlay containing clipped and unclipped graphics of Colorado.
    @StateObject private var coloradoGraphicsOverlay = GraphicsOverlay(graphics: [
        Graphic(geometry: .coloradoEnvelope, symbol: .coloradoFill)
    ])
    
    /// The graphics overlay containing graphics of the other envelopes, outlined by a dotted red line.
    @StateObject private var envelopesGraphicsOverlay = GraphicsOverlay(
        graphics: Geometry.envelopes.map {
            Graphic(geometry: $0, symbol: SimpleLineSymbol(style: .dot, color: .red, width: 3))
        }
    )
    
    /// The unclipped graphic of Colorado.
    private var coloradoGraphic: Graphic { coloradoGraphicsOverlay.graphics.first! }
    
    /// Clips the geometry of Colorado to the given envelope.
    /// - Parameter envelope: The envelope to clip the geometry of Colorado to.
    private func clipColoradoGeometry(to envelope: Envelope) {
        // Uses the geometry engine to create a new geometry for the area of
        // Colorado that overlaps the given envelope.
        let clippedGeometry = GeometryEngine.clip(coloradoGraphic.geometry!, to: envelope)
        // Creates the clipped graphic from the clipped geometry if there is an overlap.
        let clippedGraphic = Graphic(geometry: clippedGeometry, symbol: .coloradoFill)
        // Adds the clipped graphic to the colorado graphics overlay.
        coloradoGraphicsOverlay.addGraphic(clippedGraphic)
    }
    
    var body: some View {
        MapView(map: map, graphicsOverlays: [coloradoGraphicsOverlay, envelopesGraphicsOverlay])
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button("Clip") {
                        // Disables the clip button.
                        clipIsDisabled = true
                        // Hides the Colorado graphic.
                        coloradoGraphic.isVisible = false
                        // Clips Colorado's geometry to each envelope.
                        envelopesGraphicsOverlay.graphics.forEach { clipColoradoGeometry(to: $0.geometry as! Envelope) }
                    }
                    .disabled(clipIsDisabled)
                }
            }
    }
}

private extension Symbol {
    /// The simple fill symbol for Colorado graphics.
    static var coloradoFill: SimpleFillSymbol {
        .init(
            color: .blue.withAlphaComponent(0.2),
            outline: SimpleLineSymbol(
                style: .solid,
                color: .blue,
                width: 2
            )
        )
    }
}

private extension Geometry {
    /// An envelope approximating the boundary of Colorado.
    static var coloradoEnvelope: Envelope {
        Envelope(
            xMin: -11362327.1283,
            yMin: 5012861.2903,
            xMax: -12138232.0184,
            yMax: 4441198.7738,
            spatialReference: .webMercator
        )
    }
    /// An envelope inside the boundary of Colorado.
    static var containedEnvelope: Envelope {
        Envelope(
            xMin: -11655182.5952,
            yMin: 4741618.773,
            xMax: -11431488.567,
            yMax: 4593570.0683,
            spatialReference: .webMercator
        )
    }
    /// An envelope intersecting the boundary of Colorado.
    static var intersectingEnvelope: Envelope {
        Envelope(
            xMin: -11962086.4793,
            yMin: 4566553.8814,
            xMax: -12260345.1836,
            yMax: 4332053.3784,
            spatialReference: .webMercator
        )
    }
    /// An envelope outside the boundary of Colorado.
    static var outsideEnvelope: Envelope {
        Envelope(
            xMin: -11858344.3213,
            yMin: 5147942.2252,
            xMax: -12201990.2197,
            yMax: 5297071.5773,
            spatialReference: .webMercator
        )
    }
    /// The envelopes to clip the geometry of Colorado to.
    static var envelopes: [Envelope] {
        return [.containedEnvelope, .intersectingEnvelope, .outsideEnvelope]
    }
}

private extension Envelope {
    /// Expands the envelope by a given factor.
    func expanded(by factor: Double) -> Envelope {
        let builder = EnvelopeBuilder(envelope: self)
        builder.expand(factor: factor)
        return builder.toGeometry()
    }
}
