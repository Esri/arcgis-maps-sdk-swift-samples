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
                model.tapPoint = mapPoint
            }
    }
}

private extension FindNearestVertexView {
    // The view model for this sample.
    private class Model: ObservableObject {
        /// A map with a
        var map = Map()
        
        ///
        var graphicsOverlay = GraphicsOverlay()
        
        /// The orange cross graphic for the tapped location point.
        let tappedLocationGraphic: Graphic = {
            let symbol = SimpleMarkerSymbol(style: .x, color: .orange, size: 15)
            return Graphic(symbol: symbol)
        }()
        
        /// The red diamond graphic for the nearest coordinate point.
        let nearestCoordinateGraphic: Graphic = {
            let symbol = SimpleMarkerSymbol(style: .diamond, color: .red, size: 10)
            return Graphic(symbol: symbol)
        }()
        
        /// The blue cirle graphic for the nearest vertex point.
        let nearestVertexGraphic: Graphic = {
            let symbol = SimpleMarkerSymbol(style: .circle, color: .blue, size: 15)
            return Graphic( symbol: symbol)
        }()
        
        ///
        @Published var tapPoint: Point!
        
        init() {
            // The spatial reference for the sample.
            let statePlaneCaliforniaZone5 = SpatialReference(wkid: WKID(2229)!)!
            
            /// The example polygon geometry near San Bernardino County, California.
            let polygon: Polygon = {
                let polygonBuilder = PolygonBuilder(spatialReference: statePlaneCaliforniaZone5)
                polygonBuilder.add(Point(x: 6627416.41469281, y: 1804532.53233782))
                polygonBuilder.add(Point(x: 6669147.89779046, y: 2479145.16609522))
                polygonBuilder.add(Point(x: 7265673.02678292, y: 2484254.50442408))
                polygonBuilder.add(Point(x: 7676192.55880379, y: 2001458.66365744))
                polygonBuilder.add(Point(x: 7175695.94143837, y: 1840722.34474458))
                return polygonBuilder.toGeometry()
            }()
            
            map = {
                let map = Map(spatialReference: statePlaneCaliforniaZone5)
                
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
            }()
            
            graphicsOverlay = {
                let polygonFillSymbol = SimpleFillSymbol(
                    style: .forwardDiagonal,
                    color: .green,
                    outline: SimpleLineSymbol(style: .solid, color: .green, width: 2)
                )
                // The graphic for the polygon.
                let polygonGraphic = Graphic(geometry: polygon, symbol: polygonFillSymbol)
                
                let graphicsOverlay = GraphicsOverlay()
                graphicsOverlay.addGraphics([
                    polygonGraphic,
                    nearestCoordinateGraphic,
                    tappedLocationGraphic,
                    nearestVertexGraphic
                ])
                return graphicsOverlay
            }()
        }
    }
}
