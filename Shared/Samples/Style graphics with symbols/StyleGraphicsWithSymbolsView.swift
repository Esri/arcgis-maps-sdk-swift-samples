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

struct StyleGraphicsWithSymbolsView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    var body: some View {
        // Creates a map view with a graphics overlay.
        MapView(map: model.map, graphicsOverlays: [model.graphicsOverlay])
    }
}

private extension StyleGraphicsWithSymbolsView {
    /// The model used to store the geo model and other expensive objects
    /// used in this view.
    class Model: ObservableObject {
        /// A map with ArcGIS Oceans basemap style.
        let map: Map = {
            let map = Map(basemapStyle: .arcGISOceans)
            // The initial viewpoint of the map view.
            map.initialViewpoint = Viewpoint(latitude: 56.075844, longitude: -2.681572, scale: 288895.277144)
            return map
        }()
        
        /// A graphics overlay for the map view.
        let graphicsOverlay = makeGraphicsOverlay()
        
        /// Creates a graphics overlay.
        private static func makeGraphicsOverlay() -> GraphicsOverlay {
            let graphicsOverlay = GraphicsOverlay()
            // Adds the graphics.
            graphicsOverlay.addGraphics(makeBuoyPoints())
            graphicsOverlay.addGraphics(makeText())
            graphicsOverlay.addGraphic(makeBoatTripGraphic())
            graphicsOverlay.addGraphic(makeNestingGroundGraphic())
            return graphicsOverlay
        }
        
        /// Creates an array of graphics for buoy points.
        private static func makeBuoyPoints() -> [Graphic] {
            // Defines an array of points where buoys are located.
            let buoyLocations = [
                Point(x: -2.712642647560347, y: 56.062812566811544, spatialReference: .wgs84),
                Point(x: -2.6908416959572303, y: 56.06444173689877, spatialReference: .wgs84),
                Point(x: -2.6697273884990937, y: 56.064250073402874, spatialReference: .wgs84),
                Point(x: -2.6395150461199726, y: 56.06127916736989, spatialReference: .wgs84)
            ]
            
            // Creates a marker symbol.
            let buoyMarker = SimpleMarkerSymbol(style: .circle, color: .red, size: 10)
            
            // Returns an array of graphics for the buoy locations.
            return buoyLocations.map { Graphic(geometry: $0, symbol: buoyMarker) }
        }
        
        /// Creates an array of graphics for text.
        private static func makeText() -> [Graphic] {
            // Creates the Bass Rock graphic.
            let bassRockGraphic = Graphic(
                geometry: Point(x: -2.640631, y: 56.078083, spatialReference: .wgs84),
                symbol: TextSymbol(text: "Bass Rock", color: .blue, size: 10, horizontalAlignment: .left, verticalAlignment: .bottom)
            )
            
            // Creates the Craigleith graphic.
            let craigleithGraphic = Graphic(
                geometry: Point(x: -2.720324, y: 56.073569, spatialReference: .wgs84),
                symbol: TextSymbol(text: "Craigleith", color: .blue, size: 10, horizontalAlignment: .right, verticalAlignment: .top)
            )
            
            // Returns an array of graphics for the text.
            return [bassRockGraphic, craigleithGraphic]
        }
        
        /// Creates a graphic for the boat trip.
        private static func makeBoatTripGraphic() -> Graphic {
            // Creates a line symbol.
            let lineSymbol = SimpleLineSymbol(style: .dash, color: .purple, width: 4)
            
            // Returns the boat trip graphic.
            return Graphic(geometry: .boatTrip, symbol: lineSymbol)
        }
        
        /// Creates a graphic for the nesting ground.
        private static func makeNestingGroundGraphic() -> Graphic {
            // Creates the outline and fill symbols.
            let outlineSymbol = SimpleLineSymbol(style: .dash, color: .blue, width: 1)
            let fillSymbol = SimpleFillSymbol(style: .diagonalCross, color: .green, outline: outlineSymbol)
            
            // Returns the nesting graphic.
            return Graphic(geometry: .nestingGround, symbol: fillSymbol)
        }
    }
}

private extension Geometry {
    /// The boat trip geometry.
    static var boatTrip: Geometry {
        Polyline(
            points: [
                Point(x: -2.7184791227926772, y: 56.06147084563517),
                Point(x: -2.7196807500463924, y: 56.06147084563517),
                Point(x: -2.722084004553823, y: 56.062141712059706),
                Point(x: -2.726375530459948, y: 56.06386674355254),
                Point(x: -2.726890513568683, y: 56.0660708381432),
                Point(x: -2.7270621746049275, y: 56.06779569383808),
                Point(x: -2.7255172252787228, y: 56.068753913653914),
                Point(x: -2.723113970771293, y: 56.069424653352335),
                Point(x: -2.719165766937657, y: 56.07028701581465),
                Point(x: -2.713672613777817, y: 56.070574465681325),
                Point(x: -2.7093810878716917, y: 56.07095772883556),
                Point(x: -2.7044029178205866, y: 56.07153261642126),
                Point(x: -2.698223120515766, y: 56.072394931722265),
                Point(x: -2.6923866452834355, y: 56.07325722773041),
                Point(x: -2.68672183108735, y: 56.07335303720707),
                Point(x: -2.6812286779275096, y: 56.07354465544585),
                Point(x: -2.6764221689126497, y: 56.074215311778964),
                Point(x: -2.6698990495353394, y: 56.07488595644139),
                Point(x: -2.6647492184479886, y: 56.075748196715914),
                Point(x: -2.659427726324393, y: 56.076131408423215),
                Point(x: -2.654792878345778, y: 56.07622721075461),
                Point(x: -2.651359657620878, y: 56.076514616319784),
                Point(x: -2.6477547758597324, y: 56.07708942101955),
                Point(x: -2.6450081992798125, y: 56.07814320736718),
                Point(x: -2.6432915889173625, y: 56.08025069360931),
                Point(x: -2.638656740938747, y: 56.08044227755186),
                Point(x: -2.636940130576297, y: 56.078813783674946),
                Point(x: -2.636425147467562, y: 56.07728102068079),
                Point(x: -2.637798435757522, y: 56.076610417698504),
                Point(x: -2.638656740938747, y: 56.07507756705851),
                Point(x: -2.641231656482422, y: 56.07479015077557),
                Point(x: -2.6427766058086277, y: 56.075748196715914),
                Point(x: -2.6456948434247924, y: 56.07546078543464),
                Point(x: -2.647239792750997, y: 56.074598538729404),
                Point(x: -2.6492997251859376, y: 56.072682365868616),
                Point(x: -2.6530762679833284, y: 56.0718200569986),
                Point(x: -2.655479522490758, y: 56.070861913404286),
                Point(x: -2.6587410821794135, y: 56.07047864929729),
                Point(x: -2.6633759301580286, y: 56.07028701581465),
                Point(x: -2.666637489846684, y: 56.07009538137926),
                Point(x: -2.670070710571584, y: 56.06990374599109),
                Point(x: -2.6741905754414645, y: 56.069137194910745),
                Point(x: -2.678310440311345, y: 56.06808316228391),
                Point(x: -2.682086983108735, y: 56.06789151689155),
                Point(x: -2.6868934921235956, y: 56.06760404701653),
                Point(x: -2.6911850180297208, y: 56.06722075051504),
                Point(x: -2.695133221863356, y: 56.06702910083509),
                Point(x: -2.698223120515766, y: 56.066837450202335),
                Point(x: -2.7016563412406667, y: 56.06645414607839),
                Point(x: -2.7061195281830366, y: 56.0660708381432),
                Point(x: -2.7100677320166717, y: 56.065591697864576),
                Point(x: -2.713329291705327, y: 56.06520838135397),
                Point(x: -2.7167625124302273, y: 56.06453756828941),
                Point(x: -2.718307461756433, y: 56.06348340989081),
                Point(x: -2.719165766937657, y: 56.062812566811544),
                Point(x: -2.7198524110826376, y: 56.06204587471371),
                Point(x: -2.719165766937657, y: 56.06166252294756),
                Point(x: -2.718307461756433, y: 56.06147084563517)
            ],
            spatialReference: .wgs84
        )
    }
    
    /// The nesting ground geometry.
    static var nestingGround: Geometry {
        Polygon(
            points: [
                Point(x: -2.643077012566659, y: 56.077125346044475),
                Point(x: -2.6428195210159444, y: 56.07717324600376),
                Point(x: -2.6425405718360033, y: 56.07774804087097),
                Point(x: -2.6427122328698127, y: 56.077927662508635),
                Point(x: -2.642454741319098, y: 56.07829887790651),
                Point(x: -2.641853927700763, y: 56.078526395253725),
                Point(x: -2.6409741649024867, y: 56.078801809192434),
                Point(x: -2.6399871139580795, y: 56.07881378366685),
                Point(x: -2.6394077579689705, y: 56.07908919555142),
                Point(x: -2.638764029092183, y: 56.07917301616904),
                Point(x: -2.638485079912242, y: 56.07896945149566),
                Point(x: -2.638570910429147, y: 56.078203080726844),
                Point(x: -2.63878548672141, y: 56.077568418396),
                Point(x: -2.6391931816767085, y: 56.077197195961084),
                Point(x: -2.6399441986996273, y: 56.07675411934114),
                Point(x: -2.6406523004640934, y: 56.076730169108444),
                Point(x: -2.6406737580933193, y: 56.07632301287509),
                Point(x: -2.6401802326211157, y: 56.075999679860494),
                Point(x: -2.6402446055087943, y: 56.075844000034046),
                Point(x: -2.640416266542604, y: 56.07578412301025),
                Point(x: -2.6408883343855822, y: 56.075808073830935),
                Point(x: -2.6417680971838577, y: 56.076239186057734),
                Point(x: -2.642197249768383, y: 56.076251161328514),
                Point(x: -2.6428409786451708, y: 56.07661041772168),
                Point(x: -2.643077012566659, y: 56.077125346044475)
            ],
            spatialReference: .wgs84
        )
    }
}

#Preview {
    StyleGraphicsWithSymbolsView()
}
