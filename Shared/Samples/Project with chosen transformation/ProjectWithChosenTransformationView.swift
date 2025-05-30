// Copyright 2025 Esri
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

struct ProjectWithChosenTransformationView: View {
    /// The view model for the sample.
    @State private var model = Model()
    
    /// A location callout placement.
    @State private var calloutPlacement: CalloutPlacement?
    
    /// The point where the map was tapped in its original spatial reference (WGS84).
    @State private var originalPoint: Point!
    
    /// The specific projected location after normalization.
    @State private var specificProjectedPoint: Point!
    
    /// The non-specific projected location after normalization.
    @State private var unspecifiedProjectedPoint: Point!
    
    var body: some View {
        MapView(map: model.map, graphicsOverlays: [model.graphicsOverlay])
            .interactionModes([])
            .onSingleTapGesture { _, mapPoint in
                if calloutPlacement == nil {
                    // Sets the original point to where the map was tapped.
                    originalPoint = GeometryEngine.normalizeCentralMeridian(of: mapPoint) as? Point
                    
                    // Projects to a coordinate system used in Mongolia, with WKID 28413.
                    unspecifiedProjectedPoint = GeometryEngine.project(originalPoint, into: .mongolia)
                    
                    // Creates a geographic transformation step.
                    let transformationStep = GeographicTransformationStep(wkid: .init(108055)!)!
                    
                    // Creates the transformation.
                    let transformation = GeographicTransformation(step: transformationStep)
                    
                    // Projects to a coordinate system used in Mongolia, with WKID 28413 using a transformation.
                    specificProjectedPoint = GeometryEngine.project(originalPoint, into: .mongolia, datumTransformation: transformation)
                    
                    // Updates the geometry of the point graphic.
                    model.pointGraphic.geometry = specificProjectedPoint
                    
                    // Updates the location callout placement.
                    calloutPlacement = CalloutPlacement.location(specificProjectedPoint)
                } else {
                    // Hides the callout and point graphic.
                    calloutPlacement = nil
                    model.pointGraphic.geometry = nil
                }
            }
            .callout(placement: $calloutPlacement.animation(.default.speed(2))) { _ in
                VStack(alignment: .leading) {
                    Text("Coordinates")
                        .fontWeight(.medium)
                    Text("__Original (WGS 84):__\n\(originalPoint.xyCoordinates)")
                    Text("__Projected (non-specific):__\n\(unspecifiedProjectedPoint.xyCoordinates)")
                    Text("__Projected (WKID: 108055):__\n\(specificProjectedPoint.xyCoordinates)")
                }
                .font(.callout)
                .padding(6)
            }
            .overlay(alignment: .top) {
                Text("Tap on the map.")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(.thinMaterial, ignoresSafeAreaEdges: .horizontal)
            }
    }
}

private extension ProjectWithChosenTransformationView {
    /// The model used to store the geo model and other expensive objects
    /// used in this view.
    final class Model {
        /// A map with a WGS84 world basemap and an initial viewpoint over Mongolia.
        let map: Map = {
            let portalItem = PortalItem(
                portal: .arcGISOnline(connection: .anonymous),
                id: .worldBasemap
            )
            let map = Map(item: portalItem)
            
            // The transformation used in this sample is only valid in the following area.
            let extent = Envelope(
                xRange: 87.76...119.94,
                yRange: 41.58...52.15,
                spatialReference: .wgs84
            )
            map.initialViewpoint = Viewpoint(boundingGeometry: extent)
            return map
        }()
        
        /// A graphics overlay for the circular, red marker symbol.
        let graphicsOverlay = GraphicsOverlay()
        
        /// The graphic with a circular, red marker symbol.
        let pointGraphic = Graphic(symbol: SimpleMarkerSymbol(color: .red, size: 8))
        
        init() {
            graphicsOverlay.addGraphic(pointGraphic)
        }
    }
}

private extension FormatStyle where Self == FloatingPointFormatStyle<Double> {
    /// Formats the double with four decimals places of precision.
    static var decimal: Self {
        number.precision(.fractionLength(4))
    }
}

private extension Point {
    /// The point's decimal-formatted x and y coordinates.
    var xyCoordinates: Text {
        Text("\(self.x, format: .decimal), \(self.y, format: .decimal)")
    }
}

private extension PortalItem.ID {
    /// The portal item ID of World Imagery Hybrid Basemap (WGS84).
    static var worldBasemap: Self { Self("4c2b44abaa4841d08c938f4bbb548561")! }
}

private extension SpatialReference {
    /// The spatial reference for the sample, a coordinate system used in Mongolia (WKID: 28413).
    static var mongolia: Self { SpatialReference(wkid: WKID(28413)!)! }
}

#Preview {
    ProjectWithChosenTransformationView()
}
