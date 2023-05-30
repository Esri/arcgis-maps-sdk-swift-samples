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
                model.tapLocation = mapPoint
                
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
                    Text("Proxmity Result")
                        .font(.headline)
                    Text(
                        CoordinateFormatter.latitudeLongitudeString(
                            from: model.tapLocation,
                            format: .decimalDegrees,
                            decimalPlaces: 1
                        )
                    )
                    .font(.callout)
                }
                .padding(5)
            }
    }
}

private extension FindNearestVertexView {
    // The view model for this sample.
    private class Model: ObservableObject {
        /// A map with a
        var map = Map()
        
        /// The GraphicsOverlay for the point and polygon graphics.
        let graphicsOverlay: GraphicsOverlay
        
        /// The example polygon geometry near San Bernardino County, California.
        private var polygon: Polygon
        
        /// The orange cross graphic for the tapped location point.
        let tapLocationGraphic: Graphic = {
            let symbol = SimpleMarkerSymbol(style: .x, color: .orange, size: 15)
            return Graphic(symbol: symbol)
        }()
        
        /// The blue cirle graphic for the nearest vertex point.
        let nearestVertexGraphic: Graphic = {
            let symbol = SimpleMarkerSymbol(style: .circle, color: .blue, size: 15)
            return Graphic( symbol: symbol)
        }()
        
        /// The red diamond graphic for the nearest coordinate point.
        let nearestCoordinateGraphic: Graphic = {
            let symbol = SimpleMarkerSymbol(style: .diamond, color: .red, size: 10)
            return Graphic(symbol: symbol)
        }()
        
        /// A location callout placement.
        @Published var calloutPlacement: CalloutPlacement?
        
        /// The tap locations.
        @Published var tapLocation: Point!
        
        @Published var nearestCooridnateDistance: String?
        
        @Published var nearestVertexDistance: String?
        
        init() {
            // The spatial reference for the sample.
            let statePlaneCaliforniaZone5 = SpatialReference(wkid: WKID(2229)!)!
            
            /// The example polygon geometry near San Bernardino County, California.
            polygon = {
                let polygonBuilder = PolygonBuilder(spatialReference: statePlaneCaliforniaZone5)
                polygonBuilder.add(Point(x: 6627416.41469281, y: 1804532.53233782))
                polygonBuilder.add(Point(x: 6669147.89779046, y: 2479145.16609522))
                polygonBuilder.add(Point(x: 7265673.02678292, y: 2484254.50442408))
                polygonBuilder.add(Point(x: 7676192.55880379, y: 2001458.66365744))
                polygonBuilder.add(Point(x: 7175695.94143837, y: 1840722.34474458))
                return polygonBuilder.toGeometry()
            }()
            
            map = FindNearestVertexView.Model.makeMap(
                spatialReference: statePlaneCaliforniaZone5,
                polygon: polygon
            )
            
            graphicsOverlay = FindNearestVertexView.Model.makeGraphicsOverlay(polygon: polygon)
            graphicsOverlay.addGraphics([
                tapLocationGraphic,
                nearestCoordinateGraphic,
                nearestVertexGraphic
            ])
        }
        
        ///
        private static func makeMap(spatialReference: SpatialReference, polygon: Polygon) -> Map {
            let map = Map(spatialReference: spatialReference)
            
            // Center map on polygon
            map.initialViewpoint = Viewpoint(
                center: polygon.extent.center,
                scale: 8e6)
            
            // Add feature layer to map.
            let usStatesGeneralizedLayer = FeatureLayer(
                item: PortalItem(
                    portal: .arcGISOnline(connection: .anonymous),
                    id: Item.ID(rawValue: "99fd67933e754a1181cc755146be21ca")!))
            map.addOperationalLayer(usStatesGeneralizedLayer)
            
            return map
        }
        
        ///
        private static func makeGraphicsOverlay(polygon: Polygon) -> GraphicsOverlay {
            let polygonFillSymbol = SimpleFillSymbol(
                style: .forwardDiagonal,
                color: .green,
                outline: SimpleLineSymbol(style: .solid, color: .green, width: 2)
            )
            // The graphic for the polygon.
            let polygonGraphic = Graphic(geometry: polygon, symbol: polygonFillSymbol)
            
            return GraphicsOverlay(graphics: [polygonGraphic])
        }
        
        func drawNearestPoints() {
            // Get nearest vertex and nearest coordinate results.
            let nearestVertexResult = GeometryEngine.nearestVertex(in: polygon, to: tapLocation)!
            let nearestCoordinateResult = GeometryEngine.nearestCoordinate(in: polygon, to: tapLocation)!
            
            // Set the geometries for the tapped, nearest coordinate, and
            // nearest vertex point graphics.
            tapLocationGraphic.geometry = tapLocation
            nearestVertexGraphic.geometry = nearestVertexResult.coordinate
            nearestCoordinateGraphic.geometry = nearestCoordinateResult.coordinate
            
            // Get the distance to the nearest vertex in the polygon.
            let distanceVertex = Measurement(
                value: nearestVertexResult.distance,
                unit: UnitLength.feet
            )
            // Get the distance to the nearest coordinate in the polygon.
            let distanceCoordinate = Measurement(
                value: nearestCoordinateResult.distance,
                unit: UnitLength.feet
            )
        }
    }
}
