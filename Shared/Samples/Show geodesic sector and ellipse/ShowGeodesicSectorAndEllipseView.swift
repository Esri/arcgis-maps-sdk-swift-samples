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

struct ShowGeodesicSectorAndEllipseView: View {
    @StateObject private var model = Model()
    @State private var tapPoint: Point?
    @State private var semiAxis1Length: Double = 10
    @State private var semiAxis2Length: Double = 10
    @State private var axisDirection: Double = 10
    @State private var maxSegmentLength: Double = 10
    @State private var sectorAngle: Double = 10
    @State private var startDirection: Double = 10
    @State private var maxPointCount: Double = 10
    
    //geometryType
    
    var body: some View {
        MapViewReader { proxy in
            MapView(map: model.map, graphicsOverlays: [model.graphicOverlay])
                .onSingleTapGesture { _, tapPoint in
                    self.tapPoint = tapPoint
                }
                .task(id: tapPoint) {
                    if let tapPoint {
                        await proxy.setViewpoint(Viewpoint(center: tapPoint, scale: 1e8))
                        model.updateSector(tapPoint: tapPoint)
                    }
                }
                .toolbar {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button("Angle") { }
                        Spacer()
                        Button("Axis") { }
                    }
                }
        }
    }
}


private extension ShowGeodesicSectorAndEllipseView {
    @MainActor
    class Model: ObservableObject {
        var map = Map(basemapStyle: .arcGISTopographic)
        var graphicOverlay = GraphicsOverlay()
        
        var sectorFillSymbol = SimpleFillSymbol(style: .solid, color: .green)
        var sectorLineSymbol = SimpleLineSymbol(style: .solid, color: .green, width: 3)
        var sectorMarkerSymbol = SimpleMarkerSymbol(style: .circle, color: .green, size: 3)
        
        var ellipseGraphic: Graphic!
        
        var sectorGraphic: Graphic!
        
        func updateSector(tapPoint: Point) {
            var sectorParams = GeodesicSectorParameters<ArcGIS.Polygon>()
            sectorParams.center = tapPoint
            sectorParams.axisDirection = 45
            sectorParams.maxPointCount = 100
            sectorParams.maxSegmentLength = 20
            sectorParams.sectorAngle = 90
            sectorParams.semiAxis1Length = 200
            sectorParams.semiAxis2Length = 400
            sectorParams.startDirection = 0
            
            var sectorGeometry = GeometryEngine.geodesicSector(parameters: sectorParams)
            sectorGraphic = Graphic(geometry: sectorGeometry, symbol: sectorLineSymbol)
            graphicOverlay.addGraphic(sectorGraphic)
            
            let symbol = SimpleFillSymbol(style: .solid, color: .green)
            // Creates the parameters for the ellipse.
            let parameters = GeodesicEllipseParameters<ArcGIS.Polygon>(
                axisDirection: -45,
                center: tapPoint,
                linearUnit: .kilometers,
                maxPointCount: 100,
                maxSegmentLength: 20,
                semiAxis1Length: 200,
                semiAxis2Length: 400
            )
            // Creates the geometry for the ellipse from the parameters.
            let ellipseGeometry = GeometryEngine.geodesicEllipse(parameters: parameters)
            // Creates a graphics overlay containing a graphic with the ellipse geometry.
            graphicOverlay = GraphicsOverlay(graphics: [Graphic(geometry: ellipseGeometry)])
            // Creates and assigns a simple renderer to the graphics overlay.
            graphicOverlay.renderer = SimpleRenderer(symbol: symbol)
        }
    }
}

#Preview {
    ShowGeodesicSectorAndEllipseView()
}
