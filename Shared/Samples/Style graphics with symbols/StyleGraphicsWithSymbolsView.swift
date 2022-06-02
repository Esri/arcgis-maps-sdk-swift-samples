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
    // MARK: MapView parameters
    
    /// A map with ArcGIS Oceans basemap style.
    @StateObject private var map = Map(basemapStyle: .arcGISOceans)
    
    /// A graphics overlay for the MapView.
    private let graphicsOverlay = makeGraphicsOverlay()
    
    /// The starting viewpoint of the MapView.
    private let viewpoint = Viewpoint(latitude: 56.075844, longitude: -2.681572, scale: 288895.277144)
    
    // MARK: Methods
    
    /// Creates a GraphicsOverlay.
    private static func makeGraphicsOverlay() -> GraphicsOverlay {
        let graphicsOverlay = GraphicsOverlay()
        // Adds the graphics.
        graphicsOverlay.addGraphics(makeBuoyPoints())
        graphicsOverlay.addGraphics(makeText())
        graphicsOverlay.addGraphic(makeBoatTripGraphic())
        graphicsOverlay.addGraphic(makeNestingGroundGraphic())
        return graphicsOverlay
    }
    
    /// Creates a sequence of graphics for buoy points.
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
        
        // Creates a sequence of graphics.
        let buoyGraphics = buoyLocations.map { Graphic(geometry: $0, symbol: buoyMarker) }
        return buoyGraphics
    }
    
    /// Creates a sequence of graphics for text.
    private static func makeText() -> [Graphic] {
        // Defines the text locations.
        let bassLocation = Point(x: -2.640631, y: 56.078083, spatialReference: .wgs84)
        let craigleithLocation = Point(x: -2.720324, y: 56.073569, spatialReference: .wgs84)
        
        // Creates the text symbols.
        let bassRockSymbol = TextSymbol(text: "Bass Rock", color: UIColor(red: 0, green: 0, blue: 230 / 255.0, alpha: 1), size: 10, horizontalAlignment: .left, verticalAlignment: .bottom)
        let craigleithSymbol = TextSymbol(text: "Craigleith", color: UIColor(red: 0, green: 0, blue: 230 / 255.0, alpha: 1), size: 10, horizontalAlignment: .right, verticalAlignment: .top)
        
        // Creates the graphics.
        let bassRockGraphic = Graphic(geometry: bassLocation, symbol: bassRockSymbol)
        let craigleithGraphic = Graphic(geometry: craigleithLocation, symbol: craigleithSymbol)
        return [bassRockGraphic, craigleithGraphic]
    }
    
    /// Creates a graphic for the boat trip.
    private static func makeBoatTripGraphic() -> Graphic {
        // Defines the boat route from the geometry.
        let boatRoute = boatTripGeometry
        
        // Creates a line symbol.
        let lineSymbol = SimpleLineSymbol(style: .dash, color: UIColor(red: 0.5, green: 0, blue: 0.5, alpha: 1), width: 4)
        
        // Creates the graphic.
        let boatTripGraphic = Graphic(geometry: boatRoute, symbol: lineSymbol)
        return boatTripGraphic
    }
    
    /// Creates a graphic for the nesting ground.
    private static func makeNestingGroundGraphic() -> Graphic {
        // Defines the nesting ground from the geometry.
        let nestingGround = nestingGroundGeometry
        
        // Creates the outline and fill symbols.
        let outlineSymbol = SimpleLineSymbol(style: .dash, color: UIColor(red: 0, green: 0, blue: 0.5, alpha: 1), width: 1)
        let fillSymbol = SimpleFillSymbol(style: .diagonalCross, color: UIColor(red: 0, green: 80 / 255.0, blue: 0, alpha: 1), outline: outlineSymbol)
        
        // Creates the nesting graphic.
        let nestingGraphic = Graphic(geometry: nestingGround, symbol: fillSymbol)
        return nestingGraphic
    }
    
    /// The boat trip geometry.
    private static let boatTripGeometry: Polyline = {
        // Creates a polyline.
        let boatRoute = PolylineBuilder(spatialReference: .wgs84)
        
        // Adds points to the polyline.
        boatRoute.addPoint(x: -2.7184791227926772, y: 56.06147084563517)
        boatRoute.addPoint(x: -2.7196807500463924, y: 56.06147084563517)
        boatRoute.addPoint(x: -2.722084004553823, y: 56.062141712059706)
        boatRoute.addPoint(x: -2.726375530459948, y: 56.06386674355254)
        boatRoute.addPoint(x: -2.726890513568683, y: 56.0660708381432)
        boatRoute.addPoint(x: -2.7270621746049275, y: 56.06779569383808)
        boatRoute.addPoint(x: -2.7255172252787228, y: 56.068753913653914)
        boatRoute.addPoint(x: -2.723113970771293, y: 56.069424653352335)
        boatRoute.addPoint(x: -2.719165766937657, y: 56.07028701581465)
        boatRoute.addPoint(x: -2.713672613777817, y: 56.070574465681325)
        boatRoute.addPoint(x: -2.7093810878716917, y: 56.07095772883556)
        boatRoute.addPoint(x: -2.7044029178205866, y: 56.07153261642126)
        boatRoute.addPoint(x: -2.698223120515766, y: 56.072394931722265)
        boatRoute.addPoint(x: -2.6923866452834355, y: 56.07325722773041)
        boatRoute.addPoint(x: -2.68672183108735, y: 56.07335303720707)
        boatRoute.addPoint(x: -2.6812286779275096, y: 56.07354465544585)
        boatRoute.addPoint(x: -2.6764221689126497, y: 56.074215311778964)
        boatRoute.addPoint(x: -2.6698990495353394, y: 56.07488595644139)
        boatRoute.addPoint(x: -2.6647492184479886, y: 56.075748196715914)
        boatRoute.addPoint(x: -2.659427726324393, y: 56.076131408423215)
        boatRoute.addPoint(x: -2.654792878345778, y: 56.07622721075461)
        boatRoute.addPoint(x: -2.651359657620878, y: 56.076514616319784)
        boatRoute.addPoint(x: -2.6477547758597324, y: 56.07708942101955)
        boatRoute.addPoint(x: -2.6450081992798125, y: 56.07814320736718)
        boatRoute.addPoint(x: -2.6432915889173625, y: 56.08025069360931)
        boatRoute.addPoint(x: -2.638656740938747, y: 56.08044227755186)
        boatRoute.addPoint(x: -2.636940130576297, y: 56.078813783674946)
        boatRoute.addPoint(x: -2.636425147467562, y: 56.07728102068079)
        boatRoute.addPoint(x: -2.637798435757522, y: 56.076610417698504)
        boatRoute.addPoint(x: -2.638656740938747, y: 56.07507756705851)
        boatRoute.addPoint(x: -2.641231656482422, y: 56.07479015077557)
        boatRoute.addPoint(x: -2.6427766058086277, y: 56.075748196715914)
        boatRoute.addPoint(x: -2.6456948434247924, y: 56.07546078543464)
        boatRoute.addPoint(x: -2.647239792750997, y: 56.074598538729404)
        boatRoute.addPoint(x: -2.6492997251859376, y: 56.072682365868616)
        boatRoute.addPoint(x: -2.6530762679833284, y: 56.0718200569986)
        boatRoute.addPoint(x: -2.655479522490758, y: 56.070861913404286)
        boatRoute.addPoint(x: -2.6587410821794135, y: 56.07047864929729)
        boatRoute.addPoint(x: -2.6633759301580286, y: 56.07028701581465)
        boatRoute.addPoint(x: -2.666637489846684, y: 56.07009538137926)
        boatRoute.addPoint(x: -2.670070710571584, y: 56.06990374599109)
        boatRoute.addPoint(x: -2.6741905754414645, y: 56.069137194910745)
        boatRoute.addPoint(x: -2.678310440311345, y: 56.06808316228391)
        boatRoute.addPoint(x: -2.682086983108735, y: 56.06789151689155)
        boatRoute.addPoint(x: -2.6868934921235956, y: 56.06760404701653)
        boatRoute.addPoint(x: -2.6911850180297208, y: 56.06722075051504)
        boatRoute.addPoint(x: -2.695133221863356, y: 56.06702910083509)
        boatRoute.addPoint(x: -2.698223120515766, y: 56.066837450202335)
        boatRoute.addPoint(x: -2.7016563412406667, y: 56.06645414607839)
        boatRoute.addPoint(x: -2.7061195281830366, y: 56.0660708381432)
        boatRoute.addPoint(x: -2.7100677320166717, y: 56.065591697864576)
        boatRoute.addPoint(x: -2.713329291705327, y: 56.06520838135397)
        boatRoute.addPoint(x: -2.7167625124302273, y: 56.06453756828941)
        boatRoute.addPoint(x: -2.718307461756433, y: 56.06348340989081)
        boatRoute.addPoint(x: -2.719165766937657, y: 56.062812566811544)
        boatRoute.addPoint(x: -2.7198524110826376, y: 56.06204587471371)
        boatRoute.addPoint(x: -2.719165766937657, y: 56.06166252294756)
        boatRoute.addPoint(x: -2.718307461756433, y: 56.06147084563517)
        
        return boatRoute.toGeometry()
    }()
    
    /// The nesting ground geometry.
    private static let nestingGroundGeometry: Polygon = {
        // Creates a polygon.
        let nestingGround = PolygonBuilder(spatialReference: .wgs84)
        
        // Adds points to the polygon.
        nestingGround.addPoint(x: -2.643077012566659, y: 56.077125346044475)
        nestingGround.addPoint(x: -2.6428195210159444, y: 56.07717324600376)
        nestingGround.addPoint(x: -2.6425405718360033, y: 56.07774804087097)
        nestingGround.addPoint(x: -2.6427122328698127, y: 56.077927662508635)
        nestingGround.addPoint(x: -2.642454741319098, y: 56.07829887790651)
        nestingGround.addPoint(x: -2.641853927700763, y: 56.078526395253725)
        nestingGround.addPoint(x: -2.6409741649024867, y: 56.078801809192434)
        nestingGround.addPoint(x: -2.6399871139580795, y: 56.07881378366685)
        nestingGround.addPoint(x: -2.6394077579689705, y: 56.07908919555142)
        nestingGround.addPoint(x: -2.638764029092183, y: 56.07917301616904)
        nestingGround.addPoint(x: -2.638485079912242, y: 56.07896945149566)
        nestingGround.addPoint(x: -2.638570910429147, y: 56.078203080726844)
        nestingGround.addPoint(x: -2.63878548672141, y: 56.077568418396)
        nestingGround.addPoint(x: -2.6391931816767085, y: 56.077197195961084)
        nestingGround.addPoint(x: -2.6399441986996273, y: 56.07675411934114)
        nestingGround.addPoint(x: -2.6406523004640934, y: 56.076730169108444)
        nestingGround.addPoint(x: -2.6406737580933193, y: 56.07632301287509)
        nestingGround.addPoint(x: -2.6401802326211157, y: 56.075999679860494)
        nestingGround.addPoint(x: -2.6402446055087943, y: 56.075844000034046)
        nestingGround.addPoint(x: -2.640416266542604, y: 56.07578412301025)
        nestingGround.addPoint(x: -2.6408883343855822, y: 56.075808073830935)
        nestingGround.addPoint(x: -2.6417680971838577, y: 56.076239186057734)
        nestingGround.addPoint(x: -2.642197249768383, y: 56.076251161328514)
        nestingGround.addPoint(x: -2.6428409786451708, y: 56.07661041772168)
        nestingGround.addPoint(x: -2.643077012566659, y: 56.077125346044475)
        
        return nestingGround.toGeometry()
    }()
    
    // MARK: Body
    
    var body: some View {
        // Creates a map view with the graphic overlay.
        MapView(map: map, viewpoint: viewpoint, graphicsOverlays: [graphicsOverlay])
    }
}
