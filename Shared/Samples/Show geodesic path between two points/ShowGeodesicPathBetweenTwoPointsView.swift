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
            return complete(start: start, end: end, line: line)
        }
    }
    
    @State private var tapState: TapState = .empty {
        didSet {
            updateOverlay()
            updateLength()
        }
    }
    
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
    
    private static func makePointGraphic(at point: Point) -> Graphic {
        let symbol = SimpleMarkerSymbol(style: .cross, color: .blue, size: 20)
        return Graphic(geometry: point, symbol: symbol)
    }
    
    private static func makeLineGraphic(for line: Polyline) -> Graphic {
        let symbol = SimpleLineSymbol(style: .dash, color: .yellow, width: 2)
        return Graphic(geometry: line, symbol: symbol)
    }
    
    private func updateOverlay() {
        overlay.removeAllGraphics()
        
        switch tapState {
        case .empty:
            break
        case .startOnly(let start):
            overlay.addGraphic(Self.makePointGraphic(at: start))
        case .complete(let start, let end, let line):
            overlay.addGraphic(Self.makePointGraphic(at: start))
            overlay.addGraphic(Self.makePointGraphic(at: end))
            overlay.addGraphic(Self.makeLineGraphic(for: line))
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
