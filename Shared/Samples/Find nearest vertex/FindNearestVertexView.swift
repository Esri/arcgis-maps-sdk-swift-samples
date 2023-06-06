// Copyright 2023 Esri
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

struct FindNearestVertexView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    var body: some View {
        // Create a map view to display the map.
        MapView(map: model.map, graphicsOverlays: [model.graphicsOverlay])
            .onSingleTapGesture { _, mapPoint in
                // Normalize map point.
                guard let normalizedMapPoint = GeometryEngine.normalizeCentralMeridian(of: mapPoint) as? Point else { return }
                model.tapLocation = normalizedMapPoint
                if model.calloutPlacement == nil {
                    // Draw the point graphics.
                    model.drawNearestPoints()
                    // Project the point to the WGS 84 spatial reference.
                    let location = GeometryEngine.project(mapPoint, into: .wgs84)!
                    // Show the callout at the tapped location.
                    model.calloutPlacement = CalloutPlacement.location(location)
                } else {
                    // Remove points and hide callout.
                    model.tapLocationGraphic.geometry = nil
                    model.nearestCoordinateGraphic.geometry = nil
                    model.nearestVertexGraphic.geometry = nil
                    model.calloutPlacement = nil
                }
            }
            .callout(placement: $model.calloutPlacement.animation(.default.speed(2))) { _ in
                VStack(alignment: .leading) {
                    Text("Proximity Result")
                        .font(.headline)
                    Text(
                        "Vertex dist: " +
                        model.nearestVertexDistance +
                        "; Point dist: " +
                        model.nearestCoordinateDistance
                    )
                    .font(.callout)
                }
                .padding(5)
            }
    }
}

private extension FindNearestVertexView {
    // The view model for the sample.
    private class Model: ObservableObject {
        /// A map with a generalized US states feature layer and centered on
        /// the example polygon in California.
        var map = Map()
        
        /// The graphics overlay for the point and polygon graphics.
        let graphicsOverlay = GraphicsOverlay()
        
        /// An orange cross graphic for the tap location point.
        let tapLocationGraphic: Graphic = {
            let symbol = SimpleMarkerSymbol(style: .x, color: .orange, size: 15)
            return Graphic(symbol: symbol)
        }()
        
        /// A blue circle graphic for the nearest vertex point.
        let nearestVertexGraphic: Graphic = {
            let symbol = SimpleMarkerSymbol(style: .circle, color: .blue, size: 15)
            return Graphic(symbol: symbol)
        }()
        
        /// A red diamond graphic for the nearest coordinate point.
        let nearestCoordinateGraphic: Graphic = {
            let symbol = SimpleMarkerSymbol(style: .diamond, color: .red, size: 10)
            return Graphic(symbol: symbol)
        }()
        
        /// The example polygon near San Bernardino County, California.
        private var polygon: ArcGIS.Polygon
        
        /// A distance formatter to format distance measurements and units.
        private let distanceFormatter: MeasurementFormatter = {
            let formatter = MeasurementFormatter()
            formatter.numberFormatter.maximumFractionDigits = 1
            formatter.numberFormatter.minimumFractionDigits = 1
            return formatter
        }()
        
        /// A location callout placement.
        @Published var calloutPlacement: CalloutPlacement?
        
        /// The tap location.
        @Published var tapLocation: Point!
        
        /// The nearest coordinate on the polygon to the tapLocation.
        @Published var nearestCoordinateDistance: String = ""
        
        /// The nearest vertex on the polygon to the tapLocation.
        @Published var nearestVertexDistance: String = ""
        
        init() {
            // The spatial reference for the sample.
            let statePlaneCaliforniaZone5 = SpatialReference(wkid: WKID(2229)!)!
            
            // Create the example polygon.
            polygon = {
                let polygonBuilder = PolygonBuilder(spatialReference: statePlaneCaliforniaZone5)
                polygonBuilder.add(Point(x: 6627416.41469281, y: 1804532.53233782))
                polygonBuilder.add(Point(x: 6669147.89779046, y: 2479145.16609522))
                polygonBuilder.add(Point(x: 7265673.02678292, y: 2484254.50442408))
                polygonBuilder.add(Point(x: 7676192.55880379, y: 2001458.66365744))
                polygonBuilder.add(Point(x: 7175695.94143837, y: 1840722.34474458))
                return polygonBuilder.toGeometry()
            }()
            
            // Create the map.
            map = {
                let map = Map(spatialReference: statePlaneCaliforniaZone5)
                
                // Center map on the example polygon.
                map.initialViewpoint = Viewpoint(
                    center: polygon.extent.center,
                    scale: 8e6)
                
                // Add US states feature layer to the map.
                let usStatesGeneralizedLayer = FeatureLayer(
                    item: PortalItem(
                        portal: .arcGISOnline(connection: .anonymous),
                        id: .usStatesGeneralized))
                map.addOperationalLayer(usStatesGeneralizedLayer)
                
                return map
            }()
            
            // Create graphic for the example polygon.
            let polygonFillSymbol = SimpleFillSymbol(
                style: .forwardDiagonal,
                color: .green,
                outline: SimpleLineSymbol(style: .solid, color: .green, width: 2)
            )
            let polygonGraphic = Graphic(
                geometry: polygon,
                symbol: polygonFillSymbol)
            
            // Add graphics to the graphicOverlay.
            graphicsOverlay.addGraphics([
                polygonGraphic,
                tapLocationGraphic,
                nearestCoordinateGraphic,
                nearestVertexGraphic
            ])
        }
        
        /// Draw the nearest coordinate and vertex to the tapLocation on the
        /// example polygon.
        func drawNearestPoints() {
            // Get nearest vertex and nearest coordinate results.
            var nearestVertexResult = GeometryEngine.nearestVertex(in: polygon, to: tapLocation)!
            var nearestCoordinateResult = GeometryEngine.nearestCoordinate(in: polygon, to: tapLocation)!
            
            // Set the geometries for the tapped, nearest coordinate, and
            // nearest vertex point graphics.
            tapLocationGraphic.geometry = tapLocation
            nearestVertexGraphic.geometry = nearestVertexResult.coordinate
            nearestCoordinateGraphic.geometry = nearestCoordinateResult.coordinate
            
            // Set the distance to the nearest vertex in the polygon.
            let vertexDistance = Measurement(
                value: nearestVertexResult.distance,
                unit: UnitLength.feet
            )
            nearestVertexDistance = distanceFormatter.string(from: vertexDistance)
            
            // Set the distance to the nearest coordinate in the polygon.
            let coordinateDistance = Measurement(
                value: nearestCoordinateResult.distance,
                unit: UnitLength.feet
            )
            nearestCoordinateDistance = distanceFormatter.string(from: coordinateDistance)
        }
    }
}

private extension PortalItem.ID {
    /// The ID used in the "US States Generalized" portal item.
    static var usStatesGeneralized: Self { Self("99fd67933e754a1181cc755146be21ca")! }
}
