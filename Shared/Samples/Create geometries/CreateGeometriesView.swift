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

struct CreateGeometriesView: View {
    /// The map shown in the map view.
    @State private var map: Map = {
        let map = Map(basemapStyle: .arcGISTopographic)

        // Makes an envelope to use as the map viewpoint.
        let envelopeBuilder = EnvelopeBuilder(
            envelope: Envelope(xRange: -123.0 ... -101.0, yRange: 33.5 ... 48.0, spatialReference: .wgs84)
        )
        envelopeBuilder.expand(by: 1.1)
        // Set the initial viewpoint of the map.
        map.initialViewpoint = Viewpoint(boundingGeometry: envelopeBuilder.toGeometry())
        
        return map
    }()
    
    /// The graphics overlay used to show the geometries.
    @State private var graphicsOverlay: GraphicsOverlay = {
        let graphicsOverlay = GraphicsOverlay()
        
        // Makes a point using x, y coordinates and a spatial reference.
        let point = Point(x: -117.195800, y: 34.056295, spatialReference: .wgs84)

        // Makes a multi point geometry.
        let multipoint = Multipoint(points: [
            Point(x: -121.491014, y: 38.579065, spatialReference: .wgs84), // Sacramento, CA
            Point(x: -122.891366, y: 47.039231, spatialReference: .wgs84), // Olympia, WA
            Point(x: -123.043814, y: 44.93326, spatialReference: .wgs84), // Salem, OR
            Point(x: -119.766999, y: 39.164885, spatialReference: .wgs84) // Carson City, NV
        ])

        // Makes a polyline.
        let polyline = Polyline(points: [
            Point(x: -119.992, y: 41.989, spatialReference: .wgs84),
            Point(x: -119.994, y: 38.994, spatialReference: .wgs84),
            Point(x: -114.620, y: 35.0, spatialReference: .wgs84)
        ])
        
        // Makes a polygon.
        let polygon = Polygon(points: [
            Point(x: -109.048, y: 40.998, spatialReference: .wgs84),
            Point(x: -102.047, y: 40.998, spatialReference: .wgs84),
            Point(x: -102.037, y: 36.989, spatialReference: .wgs84),
            Point(x: -109.048, y: 36.998, spatialReference: .wgs84)
        ])

        // Creates symbols for drawing graphics.
        let pointMarkerSymbol = SimpleMarkerSymbol(style: .triangle, color: .blue, size: 14)
        let multipointMarkerSymbol = SimpleMarkerSymbol(style: .circle, color: .red, size: 14)
        let lineSymbol = SimpleLineSymbol(style: .solid, color: .cyan, width: 3)
        let fillSymbol = SimpleFillSymbol(style: .cross, color: .green, outline: nil)
        
        // Adds a graphic of point, multipoint, polyline and polygon.
        graphicsOverlay.addGraphic(Graphic(geometry: point, symbol: pointMarkerSymbol))
        graphicsOverlay.addGraphic(Graphic(geometry: multipoint, symbol: multipointMarkerSymbol))
        graphicsOverlay.addGraphic(Graphic(geometry: polyline, symbol: lineSymbol))
        graphicsOverlay.addGraphic(Graphic(geometry: polygon, symbol: fillSymbol))

        return graphicsOverlay
    }()
    
    var body: some View {
        MapView(map: map, graphicsOverlays: [graphicsOverlay])
    }
}

#Preview {
    CreateGeometriesView()
}
