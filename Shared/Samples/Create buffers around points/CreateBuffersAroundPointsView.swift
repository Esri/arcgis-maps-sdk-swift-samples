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
                // Update tappedPoint and bring up input box if point is within bounds.
                if model.isWithinBounds(mapPoint) {
                    model.tappedPoint = mapPoint
                    model.inputBoxIsPresented.toggle()
                } else {
                    model.status = .outOfBoundsTap
                }
            }
            .overlay(alignment: .top) {
                Text(getStatusText(model.status))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(8)
                    .background(.thinMaterial, ignoresSafeAreaEdges: .horizontal)
            }
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    // Union toggle switch.
                    Toggle("Union", isOn: $model.shouldUnion)
                        .toggleStyle(.switch)
                        .onChange(of: model.shouldUnion) { _ in
                            if !model.bufferPoints.isEmpty {
                                model.drawBuffers()
                            }
                        }
                    // Clear button.
                    Button("Clear") {
                        model.clearBufferPoints()
                        model.status = .addPoints
                    }
                    .disabled(model.bufferPoints.isEmpty)
                }
            }
            .alert("Buffer Radius", isPresented: $model.inputBoxIsPresented, actions: {
                TextField("100", text: $model.radiusInput)
                    .keyboardType(.numberPad)
                // Input done button.
                Button("Done") {
                    model.addBufferPoint()
                    model.radiusInput = ""
                    model.drawBuffers()
                    model.status = Status.bufferCreated
                }
                // Input cancel button.
                Button("Cancel") {
                    model.radiusInput = ""
                }
                // Input box message.
            }, message: {
                Text("Please enter a number between 0 and 300 miles.")
            })
    }
}

private extension CreateBuffersAroundPointsView {
    // The view model for this sample.
    class Model: ObservableObject {
        /// A Boolean value indicating whether union is on.
        @Published var shouldUnion = false
        
        /// A Point representing where the user has tapped on the map.
        @Published var tappedPoint: Point!
        
        /// A Boolean value indicating whether the input box is showing.
        @Published var inputBoxIsPresented = false
        
        /// The input obtained from the user for the buffer radius of a point.
        @Published var radiusInput: String = ""
        
        /// The status of the sample.
        @Published var status = Status.addPoints
        
        /// A Map centered on Texas with image layers.
        let map: Map
        
        /// An Array for the graphic overlays.
        var graphicsOverlays: [GraphicsOverlay] = []
        
        /// An Array for the tapped points and their radii.
        var bufferPoints: [(point: Point, radius: Double)] = []
        
        /// A GraphicsOverlay for the boundary around the valid area of use.
        private var boundaryGraphicsOverlay: GraphicsOverlay
        
        /// A GraphicsOverlay for the points' buffers.
        private var bufferGraphicsOverlay: GraphicsOverlay
        
        /// A GraphicsOverlay for the points of the tapped locations.
        private var tappedPointsGraphicsOverlay: GraphicsOverlay
        
        /// A Polygon that represents the valid area of use for the spatial reference.
        private let boundaryPolygon: Polygon
        
        init() {
            /// The spatial reference for this sample.
            let statePlaneNorthCentralTexas = SpatialReference(wkid: WKID(32038)!)!
            
            // Create boundary polygon.
            boundaryPolygon = {
                let boundaryPoints = [
                    Point(latitude: 31.720, longitude: -103.070),
                    Point(latitude: 34.580, longitude: -103.070),
                    Point(latitude: 34.580, longitude: -94.000),
                    Point(latitude: 31.720, longitude: -94.000)
                ]
                let polygon = GeometryEngine.project(Polygon(points: boundaryPoints), into: statePlaneNorthCentralTexas)!
                return polygon
            }()
            
            // Create map.
            map = CreateBuffersAroundPointsView.Model.makeMap(
                spatialReference: statePlaneNorthCentralTexas, viewpointGeometry: boundaryPolygon
            )
            
            // Create graphics overlays.
            boundaryGraphicsOverlay = CreateBuffersAroundPointsView.Model.makeBoundaryGraphicsOverlay(
                boundaryGeometry: boundaryPolygon
            )
            bufferGraphicsOverlay = CreateBuffersAroundPointsView.Model.makeBufferGraphicsOverlay()
            tappedPointsGraphicsOverlay = CreateBuffersAroundPointsView.Model.makeTappedPointsGraphicsOverlay()
            graphicsOverlays.append(
                contentsOf: [boundaryGraphicsOverlay, bufferGraphicsOverlay, tappedPointsGraphicsOverlay]
            )
        }
        
        /// Create a map with image layers from a spatial reference.
        /// - Parameters:
        ///   - spatialReference: The spatial reference the map is derived from.
        ///   - viewpointGeometry: The geometry to center the map's viewpoint on.
        /// - Returns: A new 'Map' object with added base layers.
        private static func makeMap(spatialReference: SpatialReference, viewpointGeometry: Geometry) -> Map {
            // Create a map with the spatial reference.
            let map = Map(spatialReference: spatialReference)
            map.initialViewpoint = Viewpoint(boundingGeometry: viewpointGeometry)
            
            // Add some base layers (counties, cities, and highways).
            let usaLayer = ArcGISMapImageLayer(url: URL(
                string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/USA/MapServer"
            )!)
            map.basemap = Basemap(baseLayer: usaLayer)
            
            return map
        }
        
        /// Create a graphics overlay to show the spatial reference's valid area.
        /// - Parameter boundaryGeometry: The geometry to create the boundary graphic from.
        /// - Returns: A new 'GraphicsOverlay' object with a boundary graphic added.
        private static func makeBoundaryGraphicsOverlay(boundaryGeometry: Geometry) -> GraphicsOverlay {
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
        
        /// Check if a point is within the valid area of use for this sample.
        /// - Parameter point: A point to validate.
        /// - Returns: A 'Bool' indicating whether it is within bounds.
        func isWithinBounds(_ point: Point) -> Bool {
            guard GeometryEngine.doesGeometry(boundaryPolygon, contain: point) else {
                return false
            }
            return true
        }
        
        /// Draw points and their buffers on the map.
        func drawBuffers() {
            // Ensure that there points to draw
            guard !bufferPoints.isEmpty else {
                status = .noPoints
                return
            }
            
            // Clear existing buffers graphics before drawing.
            bufferGraphicsOverlay.removeAllGraphics()
            tappedPointsGraphicsOverlay.removeAllGraphics()
            
            // Reduce the bufferPoints tuples into points and radii arrays.
            let (points, radii) = bufferPoints.reduce(into: ([Point](), [Double]())) { (result, pointAndRadius) in
                result.0.append(pointAndRadius.point)
                result.1.append(pointAndRadius.radius)
            }
            
            // Create the buffers.
            // Notice: the radius distances has the same unit of the map's spatial reference's unit.
            // In this case, the statePlaneNorthCentralTexas spatial reference uses US feet.
            let bufferPolygon = GeometryEngine.buffer(around: points, distances: radii, shouldUnion: shouldUnion)
            
            // Add the tapped points to the tappedPointsGraphicsOverlay.
            points.forEach { point in
                tappedPointsGraphicsOverlay.addGraphic(Graphic(geometry: point))
            }
            
            // Add the buffers to the bufferGraphicsOverlay.
            bufferPolygon.forEach { buffer in
                bufferGraphicsOverlay.addGraphic(Graphic(geometry: buffer))
            }
        }
        
        /// Add a point with its radius to the bufferPoints Array.
        func addBufferPoint() {
            // Check to ensure the tappedPoint is within the boundary
            guard isWithinBounds(tappedPoint) else {
                status = .outOfBoundsTap
                return
            }
            
            if let radius = Double(radiusInput) {
                // Update the buffer radius with the text value.
                let radiusInMiles = Measurement(value: radius, unit: UnitLength.miles)
                
                // The spatial reference in this sample uses US feet as its unit.
                let radiusInFeet = radiusInMiles.converted(to: .feet).value
                
                // Add point with radius to bufferPoints Array.
                bufferPoints.append((point: tappedPoint!, radius: radiusInFeet))
            }
        }
        
        /// Clear the bufferPoints and related graphics.
        func clearBufferPoints() {
            bufferPoints.removeAll()
            bufferGraphicsOverlay.removeAllGraphics()
            tappedPointsGraphicsOverlay.removeAllGraphics()
        }
    }
}

private extension CreateBuffersAroundPointsView {
    /// An Enum for the sample status.
    enum Status {
        case addPoints
        case bufferCreated
        case outOfBoundsTap
        case noPoints
    }
    
    /// Get the text message associated with the current status for the overlay.
    /// - Returns: A status message.
    func getStatusText(_ status: Status) -> String {
        switch status {
        case .addPoints:
            return "Tap on the map to add buffers."
        case .bufferCreated:
            return "Buffer created."
        case .outOfBoundsTap:
            return "Tap within the boundary to add buffer."
        case .noPoints:
            return "Please add a point to draw the buffers."
        }
    }
}
