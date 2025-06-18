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
        }
    }
}

private extension ShowGeodesicSectorAndEllipseView {
    @MainActor
    class Model: ObservableObject {
        var graphicOverlay = GraphicsOverlay()
        var map = Map(basemapStyle: .arcGISTopographic)
        var sectorFillSymbol = SimpleFillSymbol(style: .solid, color: .green)
        var sectorLineSymbol = SimpleLineSymbol(style: .solid, color: .green, width: 3)
        var sectorMarkerSymbol = SimpleMarkerSymbol(style: .circle, color: .green, size: 3)
        
        
        var ellipseGraphic: Graphic = {
            var ellipseGraphic = Graphic()
            var ellipseLineSymbol = SimpleLineSymbol(style: .dot, color: .red, width: 2)
            ellipseGraphic.symbol = ellipseLineSymbol
            return ellipseGraphic
        }()
        
        
        
        func updateSector(tapPoint: Point) {
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
            let geometry = GeometryEngine.geodesicEllipse(parameters: parameters)
            // Creates a graphics overlay containing a graphic with the ellipse geometry.
            graphicOverlay = GraphicsOverlay(graphics: [Graphic(geometry: geometry)])
            // Creates and assigns a simple renderer to the graphics overlay.
            graphicOverlay.renderer = SimpleRenderer(symbol: symbol)
        }
    }
}

#Preview {
    ShowGeodesicSectorAndEllipseView()
}
