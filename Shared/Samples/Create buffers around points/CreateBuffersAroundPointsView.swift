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
    
    /// The status of the sample.
    @State private var status = Status.addPoints
    
    /// The point where the map was tapped.
    @State private var tapPoint: Point?
    
    /// A Boolean value indicating whether union is on.
    @State private var shouldUnion = false
    
    /// A Boolean value indicating whether the input box is showing.
    @State private var inputBoxIsPresented = false
    
    /// The input obtained from the user for the buffer radius of a point.
    @State private var bufferRadius: Double = 100
    
    var body: some View {
        // Create a map view to display the map.
        MapView(map: model.map, graphicsOverlays: model.graphicsOverlays)
            .onSingleTapGesture { _, mapPoint in
                // Update tapPoint and bring up input box if point is within bounds.
                if model.boundaryContains(mapPoint) {
                    tapPoint = mapPoint
                    inputBoxIsPresented = true
                } else {
                    status = .outOfBoundsTap
                }
            }
            .overlay(alignment: .top) {
                Text(status.label)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(8)
                    .background(.thinMaterial, ignoresSafeAreaEdges: .horizontal)
            }
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    // Union toggle switch.
                    Toggle(shouldUnion ? "Union Enabled" : "Union Disabled", isOn: $shouldUnion)
                        .onChange(of: shouldUnion) { _ in
                            if !model.bufferPoints.isEmpty {
                                model.drawBuffers(unioned: shouldUnion)
                            }
                        }
                    Button("Clear") {
                        model.clearBufferPoints()
                        status = .addPoints
                    }
                    .disabled(model.bufferPoints.isEmpty)
                }
            }
            .alert("Buffer Radius", isPresented: $inputBoxIsPresented, actions: {
                TextField("radius in miles", value: $bufferRadius, format: .number)
                    .keyboardType(.numberPad)
                Button("Done") {
                    guard let tapPoint else {
                        preconditionFailure("Missing tap point")
                    }

                    let newStatus: Status
                    // Check to ensure the tapPoint is within the boundary.
                    if model.boundaryContains(tapPoint) {
                        // Ensure that the input is valid.
                        if bufferRadius > 0 && bufferRadius < 300 {
                            model.addBuffer(point: tapPoint, radius: bufferRadius)
                            model.drawBuffers(unioned: shouldUnion)
                            newStatus = .bufferCreated
                        } else {
                            newStatus = .invalidInput
                        }
                    } else {
                        newStatus = .outOfBoundsTap
                    }
                    status = newStatus
                    
                    // Set the radius to default value.
                    bufferRadius = 100
                }
                Button("Cancel", role: .cancel) { bufferRadius = 100 }
                // Input alert message.
            }, message: {
                Text("Please enter a number between 0 and 300 miles.")
            })
    }
}

private extension CreateBuffersAroundPointsView {
    /// The view model for this sample.
    class Model: ObservableObject {
        /// A map centered on Texas with image layers.
        let map: Map
        
        /// The graphics overlays used in this sample.
        var graphicsOverlays: [GraphicsOverlay] { [boundaryGraphicsOverlay, bufferGraphicsOverlay, tapPointsGraphicsOverlay] }
        
        /// An array of the tapped points and their radii.
        private(set) var bufferPoints: [(point: Point, radius: Double)] = []
        
        /// The graphics overlay for the boundary around the valid area of use.
        private let boundaryGraphicsOverlay: GraphicsOverlay
        
        /// The graphics overlay for the points' buffers.
        private let bufferGraphicsOverlay: GraphicsOverlay
        
        /// The graphics overlay for the points of the tapped locations.
        private let tapPointsGraphicsOverlay: GraphicsOverlay
        
        /// A polygon that represents the valid area of use for the spatial reference.
        private let boundaryPolygon: ArcGIS.Polygon
        
        init() {
            /// The spatial reference for the sample.
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
            map = Self.makeMap(
                spatialReference: statePlaneNorthCentralTexas,
                viewpointGeometry: boundaryPolygon
            )
            
            // Create graphics overlays.
            boundaryGraphicsOverlay = Self.makeBoundaryGraphicsOverlay(
                boundaryGeometry: boundaryPolygon
            )
            bufferGraphicsOverlay = Self.makeBufferGraphicsOverlay()
            tapPointsGraphicsOverlay = Self.makeTappedPointsGraphicsOverlay()
        }
        
        /// Creates a map with image layers from a spatial reference.
        /// - Parameters:
        ///   - spatialReference: The `SpatialReference` the `Map` is derived from.
        ///   - viewpointGeometry: The `Geometry` to center the map's viewpoint on.
        /// - Returns: A new `Map` object with added base layers.
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
        
        /// Creates a graphics overlay to show the spatial reference's valid area.
        /// - Parameter boundaryGeometry: The `Geometry` to create the boundary graphic from.
        /// - Returns: A new `GraphicsOverlay` object with a boundary graphic added.
        private static func makeBoundaryGraphicsOverlay(boundaryGeometry: Geometry) -> GraphicsOverlay {
            let graphicsOverlay = GraphicsOverlay()
            let lineSymbol = SimpleLineSymbol(style: .dash, color: .red, width: 5)
            let boundaryGraphic = Graphic(geometry: boundaryGeometry, symbol: lineSymbol)
            graphicsOverlay.addGraphic(boundaryGraphic)
            return graphicsOverlay
        }
        
        /// Creates a graphics overlay for the buffer graphics.
        /// - Returns: A new `GraphicsOverlay` object to be used for the buffers.
        private static func makeBufferGraphicsOverlay() -> GraphicsOverlay {
            let graphicsOverlay = GraphicsOverlay()
            let bufferPolygonOutlineSymbol = SimpleLineSymbol(style: .solid, color: .systemGreen, width: 3)
            let bufferPolygonFillSymbol = SimpleFillSymbol(style: .solid, color: .yellow.withAlphaComponent(0.6), outline: bufferPolygonOutlineSymbol)
            graphicsOverlay.renderer = SimpleRenderer(symbol: bufferPolygonFillSymbol)
            return graphicsOverlay
        }
        
        /// Creates a graphics overlay for the tapped points graphics.
        /// - Returns: A new `GraphicsOverlay` object to be used for the tapped points.
        private static func makeTappedPointsGraphicsOverlay() -> GraphicsOverlay {
            let graphicsOverlay = GraphicsOverlay()
            let circleSymbol = SimpleMarkerSymbol(style: .circle, color: .red, size: 10)
            graphicsOverlay.renderer = SimpleRenderer(symbol: circleSymbol)
            return graphicsOverlay
        }
        
        /// Checks if a point is within the valid area of use for this sample.
        /// - Parameter point: A `Point` to validate.
        /// - Returns: A `Bool` indicating whether it is within bounds.
        func boundaryContains(_ point: Point) -> Bool {
            guard GeometryEngine.doesGeometry(boundaryPolygon, contain: point) else {
                return false
            }
            return true
        }
        
        /// Draws points and their buffers on the map.
        /// - Parameter unioned: A Boolean indicating whether the buffers should be unioned.
        func drawBuffers(unioned: Bool) {
            // Clear existing buffers graphics before drawing.
            bufferGraphicsOverlay.removeAllGraphics()
            tapPointsGraphicsOverlay.removeAllGraphics()
            
            // Reduce the bufferPoints tuples into points and radii arrays.
            let (points, radii) = bufferPoints.reduce(into: ([Point](), [Double]())) { (result, pointAndRadius) in
                result.0.append(pointAndRadius.point)
                result.1.append(pointAndRadius.radius)
            }
            
            // Create the buffers.
            // Notice: the radius distances has the same unit of the map's spatial reference's unit.
            // In this case, the statePlaneNorthCentralTexas spatial reference uses US feet.
            let bufferPolygon = GeometryEngine.buffer(around: points, distances: radii, shouldUnion: unioned)
            
            // Add the tap points to the tapPointsGraphicsOverlay.
            points.forEach { point in
                tapPointsGraphicsOverlay.addGraphic(Graphic(geometry: point))
            }
            
            // Add the buffers to the bufferGraphicsOverlay.
            bufferPolygon.forEach { buffer in
                bufferGraphicsOverlay.addGraphic(Graphic(geometry: buffer))
            }
        }
        
        /// Adds a point with its radius to the buffer points array.
        /// - Parameters:
        ///   - point: The center point to create a buffer.
        ///   - radius: The radius of the buffer.
        func addBuffer(point: Point, radius: Double) {
            // Update the buffer radius with the text value.
            let radiusInMiles = Measurement(value: radius, unit: UnitLength.miles)
            
            // The spatial reference in this sample uses US feet as its unit.
            let radiusInFeet = radiusInMiles.converted(to: .feet).value
            
            // Add point with radius to bufferPoints Array.
            bufferPoints.append((point: point, radius: radiusInFeet))
        }
        
        /// Clears the bufferPoints array and related graphics.
        func clearBufferPoints() {
            bufferPoints.removeAll()
            bufferGraphicsOverlay.removeAllGraphics()
            tapPointsGraphicsOverlay.removeAllGraphics()
        }
    }
}

private extension CreateBuffersAroundPointsView {
    /// An enumeration for the sample status.
    enum Status {
        case addPoints, bufferCreated, outOfBoundsTap, invalidInput, noPoints
        
        /// The text message associated with the current status for the overlay.
        var label: String {
            switch self {
            case .addPoints: return "Tap on the map to add buffers."
            case .bufferCreated: return "Buffer created."
            case .outOfBoundsTap: return "Tap within the boundary to add buffer."
            case .invalidInput: return "Enter a value between 0 and 300 to create a buffer."
            case .noPoints: return "Add a point to draw the buffers."
            }
        }
    }
}

#Preview {
    NavigationView {
        CreateBuffersAroundPointsView()
    }
}
