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
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    var body: some View {
        // Create a map view to display the map.
        MapView(map: model.map, graphicsOverlays: model.graphicsOverlays)
            .onSingleTapGesture { _, mapPoint in
                // Save point and bring up input box when map is tapped.s
                model.tappedPoint = mapPoint
                model.inputBoxIsPresented.toggle()
            }
            .overlay(alignment: .top) {
                Text(model.getStatusText())
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(8)
                    .background(.thinMaterial, ignoresSafeAreaEdges: .horizontal)
            }
            .toolbar {
                // Union toggle switch.
                ToolbarItem(placement: .bottomBar) {
                    Toggle("Union", isOn: $model.shouldUnion)
                        .toggleStyle(.switch)
                        .onChange(of: model.shouldUnion) { _ in
                            if !model.bufferPoints.isEmpty {
                                model.drawBuffers()
                            }
                        }
                }
                // Clear button.
                ToolbarItem(placement: .bottomBar) {
                    Button("Clear") {
                        model.clearBufferPoints()
                    }
                }
            }
        // Buffer radius text box.
            .alert("Buffer Radius", isPresented: $model.inputBoxIsPresented, actions: {
                TextField("100", text: $model.radiusInput)
                    .keyboardType(.numberPad)
                // Input done button.
                Button("Done", action: {
                    model.addBufferPoint()
                    model.radiusInput = ""
                    model.drawBuffers()
                })
                // Input cancel button.
                Button("Cancel", role: .cancel, action: {
                    model.radiusInput = ""
                })
                //Input message.
            }, message: {
                Text("Please enter a number between 0 and 300 miles.")
            })
    }
}

private extension CreateBuffersAroundPointsView {
    // The view model for this sample.
    private class Model: ObservableObject {
        /// A Boolean value indicating whether union is on.
        @Published var shouldUnion = false
        
        /// A Point representing where the user has tapped on the map.
        @Published var tappedPoint: Point!
        
        /// A Boolean value indicating whether the input box is showing on the screen.
        @Published var inputBoxIsPresented = false
        
        /// The buffer radius input obtained from the user.
        @Published var radiusInput: String = ""
        
        /// The status text to display to the user.
        var status = Status.addPoints
        
        /// A map with layers centerd on Texas.
        var map = Map()
        
        /// An Array for the the graphic overlays.
        var graphicsOverlays: [GraphicsOverlay] = []
        
        /// An Array for the tapped points and their radii
        var bufferPoints: [(point: Point, radius: Double)] = []
        
        /// A graphics overlay for the boundry around the valid area of use.
        private var boundaryGraphicsOverlay: GraphicsOverlay
        
        /// A graphics overlay for the buffers.
        private var bufferGraphicsOverlay: GraphicsOverlay
        
        /// A graphics overlay for the points of the tapped locations.
        private var tappedPointsGraphicsOverlay: GraphicsOverlay
        
        /// An Enum for the sample status as shown in the overlay
        enum Status {
            case addPoints
            case buffersCreated
            case outOfBoundsTap
        }
        
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
            
            // Create map.
            map = CreateBuffersAroundPointsView.Model.makeMap(
                spatialReference: statePlaneNorthCentralTexas!, viewpointGeometry: boundaryPolygon
            )
            
            // Create graphics overlays.
            boundaryGraphicsOverlay = CreateBuffersAroundPointsView.Model.makeBoundaryGraphicsOveraly(
                boundaryGeometry: boundaryPolygon
            )
            bufferGraphicsOverlay = CreateBuffersAroundPointsView.Model.makeBufferGraphicsOverlay()
            tappedPointsGraphicsOverlay = CreateBuffersAroundPointsView.Model.makeTappedPointsGraphicsOverlay()
            graphicsOverlays.append(
                contentsOf: [boundaryGraphicsOverlay, bufferGraphicsOverlay, tappedPointsGraphicsOverlay]
            )
        }
        
        /// Create a map from a spatial reference with image layers.
        /// - Parameters:
        ///   - spatialReference: The spatial reference the map is derived from.
        ///   - viewpointGeometry: The geometry to center the viewpoint on.
        /// - Returns: A new 'Map' object with added base layers.
        private static func makeMap(spatialReference: SpatialReference, viewpointGeometry: Geometry) -> Map {
            // Create a map with a basemap.
            let map = Map(spatialReference: spatialReference)
            map.initialViewpoint = Viewpoint(boundingGeometry: viewpointGeometry)
            
            // Add some base layers (counties, cities, and highways).
            let mapServiceURL = URL(
                string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/USA/MapServer"
            )!
            let usaLayer = ArcGISMapImageLayer(url: mapServiceURL)
            map.basemap!.addBaseLayer(usaLayer)
            
            return map
        }
        
        /// Create a graphics overlay to show the spatial reference's valid area.
        /// - Parameter boundaryGeometry: The geometry to create the boundry graphic from.
        /// - Returns: A new 'GraphicsOverlay' object with a boundry graphic added.
        private static func makeBoundaryGraphicsOveraly(boundaryGeometry: Geometry) -> GraphicsOverlay {
            let graphicsOverlay = GraphicsOverlay()
            let lineSymbol = SimpleLineSymbol(style: .dash, color: .red, width: 5)
            let boundaryGraphic = Graphic(geometry: boundaryGeometry, symbol: lineSymbol)
            graphicsOverlay.addGraphic(boundaryGraphic)
            return graphicsOverlay
        }
        
        /// Create a graphics overlay for the buffer graphics.
        /// - Returns: A new 'GraphicsOverlay' object to be used for the buffers.
        private static func makeBufferGraphicsOverlay() -> GraphicsOverlay {
            let graphicsOverlay = GraphicsOverlay()
            let bufferPolygonOutlineSymbol = SimpleLineSymbol(style: .solid, color: .systemGreen, width: 3)
            let bufferPolygonFillSymbol = SimpleFillSymbol(style: .solid, color: UIColor.yellow.withAlphaComponent(0.6), outline: bufferPolygonOutlineSymbol)
            graphicsOverlay.renderer = SimpleRenderer(symbol: bufferPolygonFillSymbol)
            return graphicsOverlay
        }
        
        /// Create a graphics overlay for the tapped points graphics.
        /// - Returns: A new 'GraphicsOverlay' object to be used for the tapped points.
        private static func makeTappedPointsGraphicsOverlay() -> GraphicsOverlay {
            let graphicsOverlay = GraphicsOverlay()
            let circleSymbol = SimpleMarkerSymbol(style: .circle, color: .red, size: 10)
            graphicsOverlay.renderer = SimpleRenderer(symbol: circleSymbol)
            return graphicsOverlay
        }
        
        /// Draw points and their buffers on the map.
        func drawBuffers() {
            // Clear existing buffers graphics before drawing.
            bufferGraphicsOverlay.removeAllGraphics()
            tappedPointsGraphicsOverlay.removeAllGraphics()
            
            guard !bufferPoints.isEmpty else {
                return
            }
            
            // Reduce the bufferPoints tuples into points and radii arrays.
            let (points, radii) = bufferPoints.reduce(into: ([Point](), [Double]())) { (result, pointAndRadius) in
                result.0.append(pointAndRadius.point)
                result.1.append(pointAndRadius.radius)
            }
            
            // Create the buffers.
            // Notice: the radius distances has the same unit of the map's spatial reference's unit.
            // In this case, the statePlaneNorthCentralTexas spatial reference uses US feet.
            let bufferPolygon = GeometryEngine.buffer(around: points, distances: radii, shouldUnion: shouldUnion)
            
            // Add the tapped points to the tappedPointsGraphicsOverlas.
            points.forEach { point in
                tappedPointsGraphicsOverlay.addGraphic(Graphic(geometry: point))
            }
            
            // Add the buffers to the bufferGraphicsOverlay.
            bufferPolygon.forEach { buffer in
                bufferGraphicsOverlay.addGraphic(Graphic(geometry: buffer))
            }
        }
        
        /// Add a point with its radisu to the bufferPoints Array.
        func addBufferPoint() {
            // Update the buffer radius with the text value.
            let radiusInMiles = Measurement(value: Double(radiusInput)!, unit: UnitLength.miles)
            
            // The spatial reference in this sample uses US feet as its unit.
            let radiusInFeet = radiusInMiles.converted(to: .feet).value
            
            // Add point with radius to bufferPoints Array.
            bufferPoints.append((point: tappedPoint!, radius: radiusInFeet))
        }
        
        /// Clears the points and buffers from off the screen.
        func clearBufferPoints() {
            bufferPoints.removeAll()
            bufferGraphicsOverlay.removeAllGraphics()
            tappedPointsGraphicsOverlay.removeAllGraphics()
        }
        
        ///
        func getStatusText() -> String {
            switch status {
            case .addPoints:
                return " "
            case .buffersCreated:
                return "Buffers Created."
            case .outOfBoundsTap:
                return "Tap withing the boundary to add buffer."
            }
        }
    }
}
