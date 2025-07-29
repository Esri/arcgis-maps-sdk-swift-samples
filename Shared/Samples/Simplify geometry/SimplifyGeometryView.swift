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

struct SimplifyGeometryView: View {
    @State private var map = Map(basemapStyle: .arcGISLightGray)
    @State private var isSimplified = false
    @State private var originalOverlay = GraphicsOverlay()
    @State private var resultOverlay = GraphicsOverlay()
    @State private var polygonGraphic: Graphic?
    
    private let lineSymbol = SimpleLineSymbol(style: .solid, color: .black, width: 1)
    
    var body: some View {
        MapViewReader { mapView in
            MapView(map: map, graphicsOverlays: [originalOverlay, resultOverlay])
                .onAppear {
                    createPolygon()
                    if let polygon = polygonGraphic {
                        originalOverlay.addGraphic(polygon)
                    }
                    Task {
                        await mapView.setViewpointCenter(
                            Point(
                                x: -13500,
                                y: 6710327,
                                spatialReference: .webMercator
                            ),
                            scale: 25000
                        )
                    }
                }
        }
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button("Simplify", role: .cancel) {
                    simplifyGeometry()
                }
                .disabled(!isSimplified)
            }
            
            ToolbarItem(placement: .bottomBar) {
                Button("Reset") {
                    resultOverlay.removeAllGraphics()
                    isSimplified = false
                }
                .disabled(isSimplified)
            }
        }
    }
    
    private func createPolygon() {
        let part1 = MutablePart(
            points: [
                Point(x: -13020, y: 6710130),
                Point(x: -14160, y: 6710130),
                Point(x: -14160, y: 6709300),
                Point(x: -13020, y: 6709300),
                Point(x: -13020, y: 6710130)
            ],
            spatialReference: .webMercator
        )
        let part2 = MutablePart(
            points: [
                Point(x: -12160, y: 6710730),
                Point(x: -13160, y: 6710730),
                Point(x: -13160, y: 6709100),
                Point(x: -12160, y: 6709100),
                Point(x: -12160, y: 6710730)
            ],
            spatialReference: .webMercator
        )
        let part3 = MutablePart(
            points: [
                Point(x: -12560, y: 6710030),
                Point(x: -13520, y: 6710030),
                Point(x: -13520, y: 6709000),
                Point(x: -12560, y: 6709000),
                Point(x: -12560, y: 6710030)
            ],
            spatialReference: .webMercator
        )
        let polygonBuilder = PolygonBuilder(spatialReference: .webMercator)
        polygonBuilder.parts.append(part1)
        polygonBuilder.parts.append(part2)
        polygonBuilder.parts.append(part3)
        let polygon = polygonBuilder.toGeometry()
        let fillSymbol = SimpleFillSymbol(style: .solid, color: .clear, outline: lineSymbol)
        polygonGraphic = Graphic(geometry: polygon, symbol: fillSymbol)
    }
    
    private func simplifyGeometry() {
        guard let original = polygonGraphic?.geometry else { return }
        if !GeometryEngine.isSimple(original) {
            if let simplified = GeometryEngine.simplify(original) {
                let redSymbol = SimpleFillSymbol(style: .solid, color: .red, outline: lineSymbol)
                let resultGraphic = Graphic(geometry: simplified, symbol: redSymbol)
                resultOverlay.addGraphic(resultGraphic)
                isSimplified = true
            }
        }
    }
}

#Preview {
    SimplifyGeometryView()
}
