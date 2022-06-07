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
    /// A Boolean value indicating whether to show options.
    @State private var showOptions = false
    
    /// A map with a topographic basemap style.
    @StateObject private var map = Map(basemapStyle: .arcGISTopographic)
    
    /// The graphics overlay for displaying the geometries created via a geodetic buffer around the tap point.
    /// Green.
    @StateObject private var geodeticOverlay = makeGeodeticOverlay()
    
    /// The graphics overlay for displaying the geometries created via a planar buffer around the tap point.
    /// Red, but appears as brown when blended with the geodetic overlay.
    @StateObject private var planarOverlay = makePlanarOverlay()
    
    /// The graphics overlay for displaying the location of the tap point.
    /// White crosses.
    @StateObject private var tapLocationsOverlay = makeTapLocationsOverlay()
    
    /// The radius to pass into the buffer functions.
    @State private var bufferDistance = Measurement(value: 500, unit: UnitLength.miles)
    
    /// An array of all graphics overlays.
    private var graphicsOverlays: [GraphicsOverlay] {
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
    private func addBuffer(at point: Point) {
        // Converts the buffer distance to meters.
        let bufferRadiusInMeters = bufferDistance.converted(to: .meters).value
        
        // Ensures that the buffer radius is a positive value.
        guard bufferRadiusInMeters > 0 else { return }
        
        // Creates the geometry for the map point, buffered by the given
        // distance in respect to the geodetic spatial reference system
        // (the 3D representation of the Earth).
        if let geodeticGeometry = GeometryEngine.geodeticBuffer(
            around: point,
            distance: bufferRadiusInMeters,
            distanceUnit: .meters,
            maxDeviation: .nan,
            curveType: .geodesic
        ) {
            // Creates and adds a graphic with the geodetic geometry
            // to the geodetic overlay.
            geodeticOverlay.addGraphic(Graphic(geometry: geodeticGeometry))
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
    private func clearGraphics() {
        graphicsOverlays.forEach { $0.removeAllGraphics() }
    }
    
    var body: some View {
        VStack {
            // Creates a map view with graphics overlays.
            MapView(map: map, graphicsOverlays: graphicsOverlays)
                .onSingleTapGesture { _, mapPoint in
                    // Adds a buffer at the given map point.
                    addBuffer(at: mapPoint)
                }
            
            if showOptions {
                VStack {
                    HStack {
                        Text("Buffer Radius")
                        Spacer()
                        Text(bufferDistance, format: .measurement(width: .narrow))
                    }
                    Slider(value: $bufferDistance.value, in: 200...2000)
                }
                .padding([.horizontal, .top])
            }
            
            HStack {
                Spacer()
                Button("Options") {
                    withAnimation(.interactiveSpring()) {
                        showOptions.toggle()
                    }
                }
                Spacer()
                Button("Clear All") {
                    clearGraphics()
                }
                Spacer()
            }
            .padding()
        }
    }
}
