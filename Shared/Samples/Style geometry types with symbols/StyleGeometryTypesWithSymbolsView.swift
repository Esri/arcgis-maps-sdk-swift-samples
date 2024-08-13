// Copyright 2024 Esri
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

struct StyleGeometryTypesWithSymbolsView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// A Boolean value indicating whether the edit styles view is presented.
    @State private var isEditStyles = false
    
    var body: some View {
        MapView(map: model.map, graphicsOverlays: [model.graphicsOverlay])
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    editStylesButton
                }
            }
    }
    
    /// The button for presenting the edit styles view.
    private var editStylesButton: some View {
        Button("Edit Styles") {
            isEditStyles = true
        }
        .popover(isPresented: $isEditStyles) {
            editStyles
                .presentationDetents([.fraction(0.5)])
                .frame(idealWidth: 320, idealHeight: 380)
        }
    }
    
    /// The view for editing the styles of the geometries.
    private var editStyles: some View {
        NavigationStack {
            SymbolsEditor(model: model)
                .navigationTitle("Edit Styles")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            isEditStyles = false
                        }
                    }
                }
        }
    }
}

extension StyleGeometryTypesWithSymbolsView {
    /// The view model for the sample.
    final class Model: ObservableObject {
        /// A map with topographic basemap initially centered on Woolgarston, England.
        let map: Map = {
            let map = Map(basemapStyle: .arcGISTopographic)
            map.initialViewpoint = Viewpoint(center: Point(x: -225e3, y: 6_553e3), scale: 88e3)
            return map
        }()
        
        /// A graphics overlay for display the geometry graphics on the map view.
        let graphicsOverlay = GraphicsOverlay()
        
        /// The simple marker symbol for styling the point.
        let pointSymbol = SimpleMarkerSymbol(style: .circle, color: .purple, size: 12)
        
        /// The simple line symbol for styling the polyline.
        let polylineSymbol = SimpleLineSymbol(style: .dashDotDot, color: .red, width: 6)
        
        /// The simple fill symbol for styling the polygon.
        let polygonSymbol = SimpleFillSymbol(
            style: .forwardDiagonal,
            color: .blue,
            outline: SimpleLineSymbol(style: .solid, color: .green, width: 3)
        )
        
        init() {
            // Creates and adds graphics to the graphics overlay.
            let graphics = makeGraphics()
            graphicsOverlay.addGraphics(graphics)
        }
        
        /// Creates the graphics for the sample.
        /// - Returns: Graphics with a geometry and symbol.
        private func makeGraphics() -> [Graphic] {
            // Creates graphics using a geometry and symbol.
            let point = Point(x: -225e3, y: 6_560e3)
            let pointGraphic = Graphic(geometry: point, symbol: pointSymbol)
            
            let polyline = Polyline(points: [
                Point(x: -223e3, y: 6_559e3),
                Point(x: -227e3, y: 6_559e3)
            ])
            let polylineGraphic = Graphic(geometry: polyline, symbol: polylineSymbol)
            
            let polygon = Polygon(points: [
                Point(x: -222e3, y: 6_558e3),
                Point(x: -228e3, y: 6_558e3),
                Point(x: -228e3, y: 6_555e3),
                Point(x: -222e3, y: 6_555e3)
            ])
            let polygonGraphic = Graphic(geometry: polygon, symbol: polygonSymbol)
            
            // Creates graphics using points and picture marker symbols.
            let pinSymbol = makePictureMarkerSymbolFromImage()
            let pinPoint = Point(x: -226_770, y: 6_550_470)
            let pinGraphic = Graphic(geometry: pinPoint, symbol: pinSymbol)
            
            let campsiteSymbol = makePictureMarkerSymbolFromURL()
            let campsitePoint = Point(x: -223_560, y: 6_552_020)
            let campsiteGraphic = Graphic(geometry: campsitePoint, symbol: campsiteSymbol)
            
            return [pointGraphic, polylineGraphic, polygonGraphic, pinGraphic, campsiteGraphic]
        }
        
        /// Creates a picture marker symbol from an image in the project assets.
        /// - Returns: A new `PictureMarkerSymbol` object.
        private func makePictureMarkerSymbolFromImage() -> PictureMarkerSymbol {
            let pinSymbol = PictureMarkerSymbol(image: .pinBlueStar)
            
            // Changes the symbol's offset, so the symbol aligns properly to the point.
            pinSymbol.offsetY = pinSymbol.image!.size.height / 2
            
            return pinSymbol
        }
        
        /// Creates a picture marker symbol using a remote image.
        /// - Returns: A new `PictureMarkerSymbol` object.
        private func makePictureMarkerSymbolFromURL() -> PictureMarkerSymbol {
            let imageURL = URL(
                string: "https://static.arcgis.com/images/Symbols/OutdoorRecreation/Camping.png"
            )!
            let campsiteSymbol = PictureMarkerSymbol(url: imageURL)
            
            campsiteSymbol.width = 25
            campsiteSymbol.height = 25
            
            return campsiteSymbol
        }
    }
}

#Preview {
    StyleGeometryTypesWithSymbolsView()
}
