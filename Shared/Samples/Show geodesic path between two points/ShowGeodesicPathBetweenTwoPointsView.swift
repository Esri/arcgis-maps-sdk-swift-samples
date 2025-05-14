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

struct ShowGeodesicPathBetweenTwoPointsView: View {
    @State private var map = Map(basemapStyle: .arcGISImageryStandard)
    @State private var overlay = {
        let overlay = GraphicsOverlay()
        return overlay
    }()
    @State private var length: Measurement<UnitLength>?
    
    enum TapState {
        case empty
        case startOnly(start: Point)
        case complete(start: Point, end: Point, line: Polyline)
        
        static func complete(start: Point, end: Point) -> Self {
            let line = Polyline(points: [start, end])
            let geodesicLine = GeometryEngine.geodeticDensify(
                line,
                maxSegmentLength: 1,
                lengthUnit: .kilometers,
                curveType: .geodesic
            ) as! Polyline
            return complete(start: start, end: end, line: geodesicLine)
        }
    }
    
    @State private var tapState: TapState = .empty {
        didSet {
            updateOverlay()
            updateLength()
        }
    }
    
    private let pointSymbol: Symbol = {
        SimpleMarkerSymbol(style: .cross, color: .blue, size: 20)
    }()
    
    private let lineSymbol: Symbol = {
        SimpleLineSymbol(style: .dash, color: .yellow, width: 2)
    }()
    
    var body: some View {
        MapView(map: map, graphicsOverlays: [overlay])
            .onSingleTapGesture { _, mapPoint in
                switch tapState {
                case .empty, .complete:
                    tapState = .startOnly(start: mapPoint)
                case .startOnly(let start):
                    tapState = .complete(start: start, end: mapPoint)
                }
            }
            .overlay {
                if let length {
                    Text(length.formatted())
                        .foregroundStyle(.yellow)
                }
            }
    }
    
    private func updateOverlay() {
        overlay.removeAllGraphics()
        
        switch tapState {
        case .empty:
            break
        case .startOnly(let start):
            overlay.addGraphic(Graphic(geometry: start, symbol: pointSymbol))
        case .complete(let start, let end, let line):
            overlay.addGraphic(Graphic(geometry: start, symbol: pointSymbol))
            overlay.addGraphic(Graphic(geometry: end, symbol: pointSymbol))
            overlay.addGraphic(Graphic(geometry: line, symbol: lineSymbol))
        }
    }
    
    private func updateLength() {
        switch tapState {
        case .empty, .startOnly:
            length = nil
        case .complete(_, _, let line):
            let geodeticLength = GeometryEngine.geodeticLength(of: line, lengthUnit: .meters, curveType: .geodesic)
            length = .init(value: geodeticLength, unit: .meters)
        }
    }
}

#Preview {
    ShowGeodesicPathBetweenTwoPointsView()
}
