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
    /// The model used to store the geo model and other expensive objects
    /// used in this view.
    private class Model: ObservableObject {
        /// A map with layers centerd on Texas.
        var map = Map()
        
        /// An array for the all the graphic overlays
        var graphicsOverlays: [GraphicsOverlay] = []
        
        init() {
            /// A polygon that represents the valid area of use for the spatial reference.
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
            graphicsOverlays.append(makeBoundaryGraphicsOveraly(boundaryGeometry: boundaryPolygon))
            graphicsOverlays.append(makeBufferGraphicsOverlay())
            graphicsOverlays.append(makeTappedLocationsGraphicsOverlay())
            
            // create a white cross marker symbol to show where the user clicked
            let markerSymbol = SimpleMarkerSymbol(style: .cross, color: .white, size: 14)
            // create a semi-transparent
            let fillSymbol = SimpleFillSymbol(style: .solid, color: .purple, outline: SimpleLineSymbol(style: .solid, color: .red, width: 3))
        }
        
        /// Create a map with some image laters
        private func makeMap(spatialReference: SpatialReference, viewpointGeometry: Geometry) -> Map {
            // Create a map with a basemap.
            let map = Map(spatialReference: spatialReference)
            map.initialViewpoint = Viewpoint(boundingGeometry: viewpointGeometry)
            
            // Add some base layers (counties, cities, and highways).
            let mapServiceURL = URL(string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/USA/MapServer")!
            let usaLayer = ArcGISMapImageLayer(url: mapServiceURL)
            map.basemap!.addBaseLayer(usaLayer)
            
            return map
        }
        
        /// Creates a graphics overlay to show the spatial reference's valid area.
        private func makeBoundaryGraphicsOveraly(boundaryGeometry: Geometry) -> GraphicsOverlay {
            let graphicsOverlay = GraphicsOverlay()
            let lineSymbol = SimpleLineSymbol(style: .dash, color: .red, width: 5)
            let boundaryGraphic = Graphic(geometry: boundaryGeometry, symbol: lineSymbol)
            graphicsOverlay.addGraphic(boundaryGraphic)
            return graphicsOverlay
        }
        
        /// Creates a graphics overlay for the buffer graphics.
        private func makeBufferGraphicsOverlay() -> GraphicsOverlay {
            let graphicsOverlay = GraphicsOverlay()
            let bufferPolygonOutlineSymbol = SimpleLineSymbol(style: .solid, color: .systemGreen, width: 3)
            let bufferPolygonFillSymbol = SimpleFillSymbol(style: .solid, color: UIColor.yellow.withAlphaComponent(0.6), outline: bufferPolygonOutlineSymbol)
            graphicsOverlay.renderer = SimpleRenderer(symbol: bufferPolygonFillSymbol)
            return graphicsOverlay
        }
        
        // Creates a graphics overlay for the tapped locations graphics
        func makeTappedLocationsGraphicsOverlay() -> GraphicsOverlay {
            let graphicsOverlay = GraphicsOverlay()
            let circleSymbol = SimpleMarkerSymbol(style: .circle, color: .red, size: 10)
            graphicsOverlay.renderer = SimpleRenderer(symbol: circleSymbol)
            return graphicsOverlay
        }
    }
    
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// A Boolean value indicating whether union is on.
    @State private var unionIsOn = false
    
    /// A point representing where the user has tapped.
    @State private var tapLocation: Point!
    
    /// A Boolean value indicating whether the input box is showing on the screen.
    @State private var inputBoxIsPresented = false
    
    ///
    @State private var bufferRadiusInput: String = ""
    
    var body: some View {
        // Creates a map view to display the map.
        MapView(map: model.map, graphicsOverlays: model.graphicsOverlays)
            .onSingleTapGesture { _, mapPoint in
                tapLocation = mapPoint
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
            .alert("Login", isPresented: $inputBoxIsPresented, actions: {
                TextField("100", text: $bufferRadiusInput)
                
                
                
                Button("Done", action: {
                    
                })
                Button("Cancel", role: .cancel, action: {})
            }, message: {
                Text("Please enter your username and password.")
            })
    }
}
