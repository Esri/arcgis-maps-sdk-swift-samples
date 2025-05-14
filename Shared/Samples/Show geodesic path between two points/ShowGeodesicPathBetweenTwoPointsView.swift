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
    /// The map that will be displayed in the map view.
    @State private var map = Map(basemapStyle: .arcGISImageryStandard)
    
    /// The graphics overlay that will be displayed on the map view.
    /// This will hold the graphics that show the start point, end point,
    /// and geodesic path.
    @State private var overlay = {
        let overlay = GraphicsOverlay()
        return overlay
    }()
    
    /// The current measurement state.
    @State private var state: MeasurementState = .empty {
        didSet {
            updateGraphicsOverlay()
        }
    }
    
    /// The symbology for point graphics.
    private let pointSymbol: Symbol = {
        SimpleMarkerSymbol(style: .cross, color: .blue, size: 20)
    }()
    
    /// The symbology for the line graphic.
    private let lineSymbol: Symbol = {
        SimpleLineSymbol(style: .dash, color: .yellow, width: 2)
    }()
    
    var body: some View {
        MapView(map: map, graphicsOverlays: [overlay])
            .onSingleTapGesture { _, mapPoint in
                switch state {
                case .empty, .complete:
                    // If the state is empty or complete, then start a new
                    // path, adding the tap point as the first graphic.
                    state = .startOnly(start: mapPoint)
                case .startOnly(let start):
                    // If the state was started, then add the end point
                    // to complete it.
                    state = .complete(start: start, end: mapPoint)
                }
            }
            .overlay(alignment: .top) {
                VStack {
                    switch state {
                    case .empty, .startOnly:
                        Text("Tap on the map to show a geodesic path")
                    case .complete(_, _, _, let length):
                        Text(length.formatted())
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
            }
            .animation(.default, value: state)
    }
    
    /// Update the graphics overlay for the current state.
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
    /// A value that represents the measurement state of the view.
    enum MeasurementState: Equatable {
        /// No measurement started.
        case empty
        /// Only have a starting point.
        case startOnly(start: Point)
        /// Completed measurement.
        case complete(start: Point, end: Point, line: Polyline, length: Measurement<UnitLength>)
        
        /// Creates a `complete` measurement state with a start and end point,
        /// calculating the line and length.
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
            
            let geodeticDistance = GeometryEngine.geodeticDistance(
                from: start,
                to: end,
                distanceUnit: .meters,
                azimuthUnit: .degrees,
                curveType: .geodesic
            )!
            
            print(" ")
            print("-- length of geodesic line: \(GeometryEngine.length(of: geodesicLine))")
            print("-- geodesic length of geodesic line: \(geodesicLength)")
            print("-- geodesic distance: \(geodeticDistance)")
            
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
