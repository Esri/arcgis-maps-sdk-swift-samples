// Copyright 2022 Esri
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

import SwiftUI
import ArcGIS

struct CreatePlanarAndGeodeticBuffersView: View {
    /// A Boolean value indicating whether the settings are showing.
    @State private var isShowingSettings = false
    
    /// The possible radii for buffers in miles.
    private let bufferRadii = Measurement.rMin...Measurement.rMax
    
    /// The radius to pass into the buffer functions.
    @State private var bufferDistance = Measurement(value: 500, unit: UnitLength.miles)
    
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    var body: some View {
        VStack {
            // Creates a map view with graphics overlays.
            MapView(map: model.map, graphicsOverlays: model.graphicsOverlays)
                .onSingleTapGesture { _, mapPoint in
                    // Adds a buffer at the given map point.
                    model.addBuffer(at: mapPoint, bufferDistance: bufferDistance)
                }
                .toolbar {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Toggle("Settings", isOn: $isShowingSettings.animation())
                        Spacer()
                        Button("Clear") {
                            model.removeAllBufferGraphics()
                        }
                    }
                }
            
            if isShowingSettings {
                VStack {
                    Slider(value: $bufferDistance.value, in: bufferRadii.doubleRange) {
                        Text("Buffer Radius")
                    } minimumValueLabel: {
                        Text(bufferRadii.lowerBound, format: .measurement(width: .narrow))
                    } maximumValueLabel: {
                        Text(bufferRadii.upperBound, format: .measurement(width: .narrow))
                    }
                    
                    Text("Buffer radius: \(bufferDistance, format: .measurement(width: .abbreviated))")
                }
                .padding([.horizontal, .top])
            }
        }
    }
}

private extension CreatePlanarAndGeodeticBuffersView {
    /// The model used to store the geo model and other expensive objects
    /// used in this view.
    class Model: ObservableObject {
        /// A map with a topographic basemap style.
        let map = Map(basemapStyle: .arcGISTopographic)
        
        /// The graphics overlay for displaying the geometries created via a geodetic buffer around the tap point.
        /// Contains graphics with green fill and black outline symbols.
        private let geodeticOverlay = makeGeodeticOverlay()
        
        /// The graphics overlay for displaying the geometries created via a planar buffer around the tap point.
        /// Contains graphics with red fill and black outline symbols.
        /// The red fill symbol appears brown when blended with the geodetic overlay.
        private let planarOverlay = makePlanarOverlay()
        
        /// The graphics overlay for displaying the location of the tap point.
        /// Contains graphics with white cross symbols.
        private let tapLocationsOverlay = makeTapLocationsOverlay()
        
        /// The graphics overlays used in this sample.
        var graphicsOverlays: [GraphicsOverlay] {
            return [geodeticOverlay, planarOverlay, tapLocationsOverlay]
        }
        
        /// Creates a graphics overlay for the geodetic overlay.
        private static func makeGeodeticOverlay() -> GraphicsOverlay {
            let overlay = GraphicsOverlay()
            let outlineSymbol = SimpleLineSymbol(style: .solid, color: .black, width: 2)
            let fillSymbol = SimpleFillSymbol(style: .solid, color: .green, outline: outlineSymbol)
            overlay.renderer = SimpleRenderer(symbol: fillSymbol)
            overlay.opacity = 0.5
            return overlay
        }
        
        /// Creates a graphics overlay for the planar overlay.
        private static func makePlanarOverlay() -> GraphicsOverlay {
            let overlay = GraphicsOverlay()
            let outlineSymbol = SimpleLineSymbol(style: .solid, color: .black, width: 2)
            let fillSymbol = SimpleFillSymbol(style: .solid, color: .red, outline: outlineSymbol)
            overlay.renderer = SimpleRenderer(symbol: fillSymbol)
            overlay.opacity = 0.5
            return overlay
        }
        
        /// Creates a graphics overlay for the tap locations overlay.
        private static func makeTapLocationsOverlay() -> GraphicsOverlay {
            let overlay = GraphicsOverlay()
            let symbol = SimpleMarkerSymbol(style: .cross, color: .white, size: 14)
            overlay.renderer = SimpleRenderer(symbol: symbol)
            return overlay
        }
        
        /// Adds a buffer at a given point.
        /// - Parameters:
        ///   - point: The center of the new buffer.
        ///   - bufferDistance: The radius of the new buffer.
        func addBuffer(at point: Point, bufferDistance: Measurement<UnitLength>) {
            // Converts the buffer distance to meters.
            let bufferRadiusInMeters = bufferDistance.converted(to: .meters).value
            
            // Creates the geometry for the map point, buffered by the given
            // distance in respect to the geodetic spatial reference system
            // (the 3D representation of the Earth).
            if let geodesicGeometry = GeometryEngine.geodeticBuffer(
                around: point,
                distance: bufferRadiusInMeters,
                distanceUnit: .meters,
                maxDeviation: .nan,
                curveType: .geodesic
            ) {
                // Creates and adds a graphic with the geodesic geometry
                // to the geodetic overlay.
                geodeticOverlay.addGraphic(Graphic(geometry: geodesicGeometry))
            }
            
            // Creates the geometry for the map point, buffered by the given
            // distance in respect to the projected map spatial reference system.
            if let planarGeometry = GeometryEngine.buffer(
                around: point,
                distance: bufferRadiusInMeters
            ) {
                // Creates and adds a graphic with the planar geometry
                // to the planar overlay.
                planarOverlay.addGraphic(Graphic(geometry: planarGeometry))
            }
            
            // Creates and adds a graphic symbolizing the tap location
            // to the tap locations overlay.
            tapLocationsOverlay.addGraphic(Graphic(geometry: point))
        }
        
        /// Removes all graphics from all graphics overlays.
        func removeAllBufferGraphics() {
            graphicsOverlays.forEach { $0.removeAllGraphics() }
        }
    }
}

private extension ClosedRange where Bound == Measurement<UnitLength> {
    /// The measurement's values as a closed range of doubles.
    var doubleRange: ClosedRange<Double> { self.lowerBound.value...self.upperBound.value }
}

private extension Measurement where UnitType == UnitLength {
    /// The minimum radius.
    static var rMin: Self { Measurement(value: 200, unit: UnitLength.miles) }
    /// The maximum radius.
    static var rMax: Self { Measurement(value: 2_000, unit: UnitLength.miles) }
}

#Preview {
    CreatePlanarAndGeodeticBuffersView()
}
