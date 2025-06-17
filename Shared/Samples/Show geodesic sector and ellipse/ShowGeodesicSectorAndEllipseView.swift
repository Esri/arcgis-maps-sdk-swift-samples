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
    /// The error shown in the error alert.
    @State private var error: Error?
//    @State private var model = Model()
    @State var map = Map(basemapStyle: .arcGISImageryStandard)
    @State var sectorParameters : GeodesicSectorParameters? = nil
    @State var ellipseParameters : GeodesicEllipseParameters? = nil
    var sectorFillSymbol: SimpleFillSymbol?
    var sectorLineSymbol: SimpleLineSymbol?
    var sectorMarkerSymbol: SimpleMarkerSymbol?
    var ellipseGraphic: Graphic?
    /// A Boolean value indicating whether the settings are presented.
    @State private var settingsArePresented = false
    /// The point on the screen the user tapped.
    @State private var tappedScreenPoint: CGPoint?
    @State private var tappedMapPoint: Point?
    
    let geometryOverlay: GraphicsOverlay = {
        let overlay = GraphicsOverlay(renderingMode: .dynamic)
        overlay.id = "Graphics Overlay"
        return overlay
    }()
    
    var body: some View {
        MapViewReader { proxy in
            MapView(map: map)
                .onSingleTapGesture { screenPoint, mapPoint in
                    tappedScreenPoint = screenPoint
                    tappedMapPoint = mapPoint
                    print(mapPoint)
                }
                .task(id: tappedMapPoint) {
                    await proxy.setViewpointCenter(tappedMapPoint!)
                    let geometry = GeometryEngine.geodesicEllipse(parameters: ellipseParameters!)
                    let overlay = GraphicsOverlay(graphics: [Graphic(geometry: geometry)])
                }
                .toolbar {
                    
                }
                .errorAlert(presentingError: $error)
        }
    }
    
    private func setupSector() {
//        sectorParameters = GeodesicSectorParameters(axisDirection: 1, maxPointCount: 100, maxSegmentLength: 1000, geometryType: Geometry.Type.lines, center: Point(x: 0, y: 0))
//        sectorParameters?.axisDirection = 0.5
//       / sectorParameters?.maxPointCount = 100
//        sectorParameters?.maxSegmentLength = 1000
//        sectorParameters?.geometryType = Geometry.Dimension.point
    }
    
}

private extension ShowGeodesicSectorAndEllipseView {
    /// The model used to store the geo model and other expensive objects
    /// used in this view.
    class Model: ObservableObject {
        @State var map = Map(basemapStyle: .arcGISImageryStandard)
        @State var sectorParameters : GeodesicSectorParameters? = nil
        @State var ellipseParameters : GeodesicEllipseParameters? = nil
        var sectorFillSymbol: SimpleFillSymbol?
        var sectorLineSymbol: SimpleLineSymbol?
        var sectorMarkerSymbol: SimpleMarkerSymbol?
        var ellipseGraphic: Graphic?
        
        
        let geometryOverlay: GraphicsOverlay = {
            let overlay = GraphicsOverlay(renderingMode: .dynamic)
            overlay.id = "Graphics Overlay"
            return overlay
        }()
        
        init() {
//            let geometry = GeometryEngine.geodesicEllipse(parameters: ellipseParameters!)
            //                let overlay = GraphicsOverlay(graphics: [Graphic(geometry: geometry)])
        }
        
        /// Returns the symbology for graphics saved to the graphics overlay.
        /// - Parameter geometry: The geometry of the graphic to be saved.
        /// - Returns: Either a marker or fill symbol depending on the type of provided geometry.
        private func symbol(for geometry: Geometry) -> Symbol {
            switch geometry {
            case is Point, is Multipoint:
                return SimpleMarkerSymbol(style: .circle, color: .blue, size: 20)
            case is Polyline:
                return SimpleLineSymbol(color: .blue, width: 2)
            case is ArcGIS.Polygon:
                return SimpleFillSymbol(
                    color: .gray.withAlphaComponent(0.5),
                    outline: SimpleLineSymbol(color: .blue, width: 2)
                )
            default:
                fatalError("Unexpected geometry type")
            }
        }
    }
}

#Preview {
    ShowGeodesicSectorAndEllipseView()
}
