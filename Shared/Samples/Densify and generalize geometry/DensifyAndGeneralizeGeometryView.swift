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

struct DensifyAndGeneralizeGeometryView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// A Boolean value indicating whether the geometry settings sheet is showing.
    @State private var isShowingSettings = false
    
    var body: some View {
        MapView(map: model.map, graphicsOverlays: [model.graphicsOverlay])
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button("Geometry Settings") {
                        isShowingSettings = true
                    }
                    .sheet(isPresented: $isShowingSettings, detents: [.medium], dragIndicatorVisibility: .visible) {
                        SettingsView(model: model)
                    }
                }
            }
    }
}

extension DensifyAndGeneralizeGeometryView {
    /// The view model for the sample.
    class Model: ObservableObject {
        /// A map with a Streets (Night) basemap.
        let map = Map(basemapStyle: .arcGISStreetsNight)
        
        /// The graphics overlay for all of the graphics.
        let graphicsOverlay: GraphicsOverlay
        
        /// The base polyline geometry that is densified and generalized.
        private let originalPolyline: Polyline
        
        /// The graphic for displaying the points of the resultant geometry.
        private let resultPointsGraphic: Graphic = {
            let symbol = SimpleMarkerSymbol(style: .circle, color: .magenta, size: 7)
            return Graphic(symbol: symbol)
        }()
        
        /// The graphic for displaying the lines of the resultant geometry.
        private let resultPolylineGraphic: Graphic = {
            let symbol = SimpleLineSymbol(style: .solid, color: .magenta, width: 3)
            return Graphic(symbol: symbol)
        }()
        
        /// A mutable point collection from which the original polyline and
        /// multipoint geometries are made.
        private let pointCollection = MutablePointCollection(
            points: [
                Point(x: 2330611.130549, y: 202360.002957),
                Point(x: 2330583.834672, y: 202525.984012),
                Point(x: 2330574.164902, y: 202691.488009),
                Point(x: 2330689.292623, y: 203170.045888),
                Point(x: 2330696.773344, y: 203317.495798),
                Point(x: 2330691.419723, y: 203380.917080),
                Point(x: 2330435.065296, y: 203816.662457),
                Point(x: 2330369.500800, y: 204329.861789),
                Point(x: 2330400.929891, y: 204712.129673),
                Point(x: 2330484.300447, y: 204927.797132),
                Point(x: 2330514.469919, y: 205000.792463),
                Point(x: 2330638.099138, y: 205271.601116),
                Point(x: 2330725.315888, y: 205631.231308),
                Point(x: 2330755.640702, y: 206433.354860),
                Point(x: 2330680.644719, y: 206660.240923),
                Point(x: 2330386.957926, y: 207340.947204),
                Point(x: 2330485.861737, y: 207742.298501)
            ],
            // The spatial reference for the sample, NAD83 / Oregon North.
            spatialReference: SpatialReference(wkid: WKID(rawValue: 32126)!)
        )
        
        /// A Boolean indicating whether to generalize.
        @Published var shouldGeneralize = false
        
        /// The max deviation for generalization.
        @Published var maxDeviation = 10.0
        
        /// A Boolean indicating whether to densify.
        @Published var shouldDensify = false
        
        /// The max segment length for densifying.
        @Published var maxSegmentLength = 100.0
        
        init() {
            originalPolyline = Polyline(points: pointCollection)
            
            // Set the initial viewpoint to show the extent of the polyline.
            map.initialViewpoint = Viewpoint(
                center: originalPolyline.extent.center,
                scale: 65907
            )
            
            // Create graphics overlay.
            let multipoint = Multipoint(points: pointCollection)
            
            // Create graphics for displaying the base points and lines.
            let originalPolylineGraphic = Graphic(
                geometry: originalPolyline,
                symbol: SimpleLineSymbol(style: .dot, color: .red, width: 3)
            )
            let originalPointsGraphic = Graphic(
                geometry: multipoint,
                symbol: SimpleMarkerSymbol(style: .circle, color: .red, size: 7)
            )
            
            // Add the graphics in the order we want them to appear, back to front.
            graphicsOverlay = GraphicsOverlay(graphics: [
                originalPointsGraphic,
                originalPolylineGraphic,
                resultPointsGraphic,
                resultPolylineGraphic
            ])
        }
        
        /// Resets the model values to the originals.
        func reset() {
            shouldDensify = false
            maxDeviation = 10.0
            shouldGeneralize = false
            maxSegmentLength = 100.0
            updateGraphics()
        }
        
        /// Updates the result polyline and multipoint graphics after densifying
        /// and generalizing.
        func updateGraphics() {
            // Reset the result graphics if there are no operations to do.
            if !shouldGeneralize && !shouldDensify {
                resultPolylineGraphic.geometry = nil
                resultPointsGraphic.geometry = nil
                return
            }
            
            // Start with original polyline.
            var resultPolyline = originalPolyline
            
            // Generalize the polyline with the specified max deviation.
            if shouldGeneralize {
                resultPolyline = GeometryEngine.generalize(
                    resultPolyline,
                    maxDeviation: maxDeviation,
                    removeDegenerateParts: true
                ) as! Polyline
            }
            // Densify the points of the polyline with the specified max segment.
            if shouldDensify {
                resultPolyline = GeometryEngine.densify(
                    resultPolyline,
                    maxSegmentLength: maxSegmentLength
                ) as! Polyline
            }
            
            // Convert the result points to an array.
            let points = resultPolyline.parts.flatMap { $0.points }
            
            // Create a multipoint geometry from the points array.
            let resultMultipoint = Multipoint(points: points)
            
            // Update the result graphics with the result geometries.
            resultPolylineGraphic.geometry = resultPolyline
            resultPointsGraphic.geometry = resultMultipoint
        }
    }
}

#Preview {
    NavigationView {
        DensifyAndGeneralizeGeometryView()
    }
}
