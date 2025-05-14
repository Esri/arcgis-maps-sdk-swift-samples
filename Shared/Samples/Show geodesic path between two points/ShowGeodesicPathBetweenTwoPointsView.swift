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
    
    @State private var state: MeasurementState = .empty {
        didSet {
            updateGraphicsOverlay()
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
                switch state {
                case .empty, .complete:
                    state = .startOnly(start: mapPoint)
                case .startOnly(let start):
                    state = .complete(start: start, end: mapPoint)
                }
            }
            .overlay(alignment: .top) {
                VStack {
                    switch state {
                    case .empty:
                        Text("Tap on the map to show a geodesic path")
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(.ultraThinMaterial)
                    case .startOnly:
                        EmptyView()
                    case .complete(_, _, _, let length):
                        Text(length.formatted())
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(.rect(cornerRadius: 10))
                            .shadow(radius: 50)
                            .padding(.top)
                    }
                }
            }
            .animation(.default, value: state)
    }
    
    private func updateGraphicsOverlay() {
        overlay.removeAllGraphics()
        
        switch state {
        case .empty:
            break
        case .startOnly(let start):
            overlay.addGraphic(Graphic(geometry: start, symbol: pointSymbol))
        case .complete(let start, let end, let line, _):
            overlay.addGraphic(Graphic(geometry: start, symbol: pointSymbol))
            overlay.addGraphic(Graphic(geometry: end, symbol: pointSymbol))
            overlay.addGraphic(Graphic(geometry: line, symbol: lineSymbol))
        }
    }
}

extension ShowGeodesicPathBetweenTwoPointsView {
    enum MeasurementState: Equatable {
        case empty
        case startOnly(start: Point)
        case complete(start: Point, end: Point, line: Polyline, length: Measurement<UnitLength>)
        
        static func complete(start: Point, end: Point) -> Self {
            let line = Polyline(points: [start, end])
            let geodesicLine = GeometryEngine.geodeticDensify(
                line,
                maxSegmentLength: 1,
                lengthUnit: .kilometers,
                curveType: .geodesic
            ) as! Polyline
            
            let geodesicLength = GeometryEngine.geodeticLength(
                of: geodesicLine,
                lengthUnit: .meters,
                curveType: .geodesic
            )
            
            return complete(
                start: start,
                end: end,
                line: geodesicLine,
                length: .init(value: geodesicLength, unit: .meters)
            )
        }
    }
}

#Preview {
    ShowGeodesicPathBetweenTwoPointsView()
}
