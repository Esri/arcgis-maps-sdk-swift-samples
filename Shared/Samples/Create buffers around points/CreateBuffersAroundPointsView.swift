// Copyright 2023 Esri
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

struct CreateBuffersAroundPointsView: View {
    private class Model: ObservableObject {
        /// A map with layers centerd on Texas.
        var map = Map()
        
        /// An array for the the graphic overlays.
        var graphicsOverlays: [GraphicsOverlay] = []
        
        /// Graphics overlay for the boundry around the valid area of use for the
        /// spatial reference.
        var boundaryGraphicsOverlay: GraphicsOverlay
        
        /// Graphics overlay for the buffers
        var bufferGraphicsOverlay: GraphicsOverlay
        
        /// Graphics overlay for the points of the tapped locations
        var tappedLocationsGraphicsOverlay: GraphicsOverlay
        
        /// An Array for the tapped points and their radii
        var bufferPoints: [(point: Point, radius: Double)] = []
        
        /// A Boolean for whether the buffers should union.
        var shouldUnion: Bool = false
        
        init() {
            /// A Polygon that represents the valid area of use for the spatial reference.
            let statePlaneNorthCentralTexas = SpatialReference(wkid: WKID(32038)!)
            let boundaryPolygon = {
                let boundaryPoints = [
                    Point(x: -103.070, y: 31.720, spatialReference: .wgs84),
                    Point(x: -103.070, y: 34.580, spatialReference: .wgs84),
                    Point(x: -94.000, y: 34.580, spatialReference: .wgs84),
                    Point(x: -94.00, y: 31.720, spatialReference: .wgs84)
                ]
                let polygon = GeometryEngine.project(Polygon(points: boundaryPoints), into: statePlaneNorthCentralTexas!)
                return polygon!
            }()
            
            map = makeMap(spatialReference: statePlaneNorthCentralTexas!, viewpointGeometry: boundaryPolygon)
            
            // Create graphics overlayers
            boundaryGraphicsOverlay = makeBoundaryGraphicsOveraly(boundaryGeometry: boundaryPolygon)
            bufferGraphicsOverlay = makeBufferGraphicsOverlay()
            tappedLocationsGraphicsOverlay = makeTappedLocationsGraphicsOverlay()
            graphicsOverlays.append(contentsOf: [boundaryGraphicsOverlay, bufferGraphicsOverlay, tappedLocationsGraphicsOverlay])
            
            // Create a white cross marker symbol to show where the user clicked
            let markerSymbol = SimpleMarkerSymbol(style: .cross, color: .white, size: 14)
            // Create a semi-transparent
            let fillSymbol = SimpleFillSymbol(style: .solid, color: .purple, outline: SimpleLineSymbol(style: .solid, color: .red, width: 3))
        }
        
        /// Create a map with some image laters
        private static func makeMap(spatialReference: SpatialReference, viewpointGeometry: Geometry) -> Map {
            // Create a map with a basemap.
            let map = Map(spatialReference: spatialReference)
            map.initialViewpoint = Viewpoint(boundingGeometry: viewpointGeometry)
            
            // Add some base layers (counties, cities, and highways).
            let mapServiceURL = URL(string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/USA/MapServer")!
            let usaLayer = ArcGISMapImageLayer(url: mapServiceURL)
            map.basemap!.addBaseLayer(usaLayer)
            
            return map
        }
        
        /// Create a graphics overlay to show the spatial reference's valid area.
        private func makeBoundaryGraphicsOveraly(boundaryGeometry: Geometry) -> GraphicsOverlay {
            let graphicsOverlay = GraphicsOverlay()
            let lineSymbol = SimpleLineSymbol(style: .dash, color: .red, width: 5)
            let boundaryGraphic = Graphic(geometry: boundaryGeometry, symbol: lineSymbol)
            graphicsOverlay.addGraphic(boundaryGraphic)
            return graphicsOverlay
        }
        
        /// Create a graphics overlay for the buffer graphics.
        private func makeBufferGraphicsOverlay() -> GraphicsOverlay {
            let graphicsOverlay = GraphicsOverlay()
            let bufferPolygonOutlineSymbol = SimpleLineSymbol(style: .solid, color: .systemGreen, width: 3)
            let bufferPolygonFillSymbol = SimpleFillSymbol(style: .solid, color: UIColor.yellow.withAlphaComponent(0.6), outline: bufferPolygonOutlineSymbol)
            graphicsOverlay.renderer = SimpleRenderer(symbol: bufferPolygonFillSymbol)
            return graphicsOverlay
        }
        
        /// Create a graphics overlay for the tapped locations graphics
        private func makeTappedLocationsGraphicsOverlay() -> GraphicsOverlay {
            let graphicsOverlay = GraphicsOverlay()
            let circleSymbol = SimpleMarkerSymbol(style: .circle, color: .red, size: 10)
            graphicsOverlay.renderer = SimpleRenderer(symbol: circleSymbol)
            return graphicsOverlay
        }
        
        /// Draw points and their buffers on the basemap
        func drawBuffers() {
            // Clear existing buffers graphics before drawing.
            bufferGraphicsOverlay.removeAllGraphics()
            tappedLocationsGraphicsOverlay.removeAllGraphics()

            guard !bufferPoints.isEmpty else {
                return
            }
            
            // Reduce the tuples into points and radii arrays.
            let (points, radii) = bufferPoints.reduce(into: ([Point](), [Double]())) { (result, pointAndRadius) in
                    result.0.append(pointAndRadius.point)
                    result.1.append(pointAndRadius.radius)
            }

            // Create the buffers.
            // Notice: the radius distances has the same unit of the map's spatial reference's unit.
            // In this case, the statePlaneNorthCentralTexas spatial reference uses US feet.
            let bufferPolygon = GeometryEngine.buffer(around: points, distances: radii, shouldUnion: shouldUnion)
            
            // Add the tapped point graphics.
            for point in points {
                tappedLocationsGraphicsOverlay.addGraphic(Graphic(geometry: point))
            }
                    
            // Add the buffer graphics.
            for buffer in bufferPolygon {
                bufferGraphicsOverlay.addGraphic(Graphic(geometry: buffer))
            }
        }
    }
    
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// A Boolean value indicating whether union is on.
    @State private var unionIsOn = false
    
    /// A Point representing where the user has tapped on the map.
    @State private var tapPoint: Point!
    
    /// A Boolean value indicating whether the input box is showing on the screen.
    @State private var inputBoxIsPresented = false
    
    /// The buffer radius input obtained from the user.
    @State private var radiusInput: String = ""
    
    var body: some View {
        // Create a map view to display the map.
        MapView(map: model.map, graphicsOverlays: model.graphicsOverlays)
            .onSingleTapGesture { _, mapPoint in
                tapPoint = mapPoint
                inputBoxIsPresented.toggle()
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Toggle("Union", isOn: $unionIsOn)
                        .toggleStyle(.switch)
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("Clear") {
                        print()
                    }
                }
            }
            .alert("Buffer Radius", isPresented: $inputBoxIsPresented, actions: {
                TextField("100", text: $radiusInput)
                    .keyboardType(.numberPad)
                Button("Done", action: {
                    // Update the buffer radius with the text value.
                    let radiusInMiles = Measurement(value: Double(radiusInput)!, unit: UnitLength.miles)
                    // The spatial reference in this sample uses US feet as its unit.
                    let radiusInFeet = radiusInMiles.converted(to: .feet).value
                    
                    model.bufferPoints.append((point: tapPoint!, radius: radiusInFeet))
                    radiusInput = ""
                })
                Button("Cancel", role: .cancel, action: {
                    radiusInput = ""
                })
            }, message: {
                Text("Please a number between 0 and 300 miles.")
            })
    }
}
