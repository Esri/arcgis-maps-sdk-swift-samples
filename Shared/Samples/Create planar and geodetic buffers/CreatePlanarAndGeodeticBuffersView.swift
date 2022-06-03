//
//  CreatePlanarAndGeodeticBuffersView.swift
//  Samples (iOS)
//
//  Created by Christopher Lee on 6/2/22.
//  Copyright © 2022 Esri. All rights reserved.
//

import SwiftUI
import ArcGIS

struct CreatePlanarAndGeodeticBuffersView: View {
    /// A Boolean value indicating whether to show the options menu.
    @State private var showOptions = false
    
    /// A map with a topographic basemap style
    @StateObject private var map = Map(basemapStyle: .arcGISTopographic)
    
    /// The graphics overlay for displaying the geometries created via a geodesic buffer around the tap point.
    /// Green.
    @StateObject private var geodeticOverlay = makeGeodeticOverlay()
    
    /// The graphics overlay for displaying the geometries created via a planar buffer around the tap point.
    /// Red, but appears as brown when blended with the geodesic overlay.
    @StateObject private var planarOverlay = makePlanarOverlay()
    
    /// The graphics overlay for displaying the location of the tap point.
    /// White crosses.
    @StateObject private var tapLocationsOverlay = makeTapLocationsOverlay()
    
    /// The radius to pass into the buffer functions.
    @State private var bufferDistance: Measurement<UnitLength> = Measurement(value: 500, unit: .miles)
    
    /// An array of all graphics overlays.
    private var graphicsOverlays: [GraphicsOverlay] {
        return [geodeticOverlay, planarOverlay, tapLocationsOverlay]
    }
    
    /// Creates a graphics overlay for the geodesic overlay.
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
        
        // Ensures tthat the buffer radius is a positive value.
        guard bufferRadiusInMeters > 0 else { return }
        
        // Creates the geometry for the map point, buffered by the given distance in respect
        // to the geodetic spatial reference system (the 3D representation of the Earth).
        if let geodesicGeoemtry = GeometryEngine.geodeticBuffer(
            around: point,
            distance: bufferRadiusInMeters,
            distanceUnit: .meters,
            maxDeviation: .nan,
            curveType: .geodesic
        ) {
            // Creates and adds a graphic with the geodesic geometry to the geodetic overlay.
            geodeticOverlay.addGraphic(Graphic(geometry: geodesicGeoemtry))
        }
        
        // Creates the geometry for the map point, buffered by the given distance in respect
        // to the projected map spatial reference system.
        if let planarGeometry = GeometryEngine.buffer(around: point, distance: bufferRadiusInMeters) {
            // Creates and adds a graphic with the planar geometry to the planar overlay.
            planarOverlay.addGraphic(Graphic(geometry: planarGeometry))
        }
        
        // Creates and adds a graphic symbolizing the tap location to the tap locations overlay.
        tapLocationsOverlay.addGraphic(Graphic(geometry: point))
    }
    
    /// Removes all graphics from each graphics overlays.
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
                    Slider(value: $bufferDistance.value, in: 200...2000, step: 1)
                }
                .padding([.horizontal, .top])
                .transition(.opacity)
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

struct CreatePlanarAndGeodeticBuffersView_Previews: PreviewProvider {
    static var previews: some View {
        CreatePlanarAndGeodeticBuffersView()
    }
}
