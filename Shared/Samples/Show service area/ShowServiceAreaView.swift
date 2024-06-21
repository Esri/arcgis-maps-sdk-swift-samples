//
//  ShowServiceAreaView.swift
//  Samples
//
//  Created by Christopher Webb on 6/21/24.
//  Copyright © 2024 Esri. All rights reserved.
//

import ArcGIS
import SwiftUI

struct ShowServiceAreaView: View {
    @StateObject private var model = Model()
    var body: some View {
        MapViewReader { mapProxy in
            MapView(
                map: model.map,
                graphicsOverlays: [
                    model.facilitiesGraphicsOverlay,
                    model.barriersGraphicsOverlay,
                    model.serviceAreaGraphicsOverlay
                ]
            )
            .onSingleTapGesture { tapPoint, point in
                model.onTap(point: point)
                Task {
                    do {
                        try await model.serviceArea()
                    } catch {
                        print(error)
                    }
                }
            }
            .task {
                do {
                    //                    try await model.setServiceArea()
                    try await model.serviceArea()
                } catch {
                    print(error)
                }
            }
        }
    }
}

private extension ShowServiceAreaView {
    @MainActor
    class Model: ObservableObject {
        /// A map with viewpoint set to Amberg, Germany.
        let map: Map = {
            let map = Map(basemapStyle: .arcGISTerrain)
            map.initialViewpoint = Viewpoint(
                center: Point(x: -13041154, y: 3858170, spatialReference: .webMercator),
                scale: 60000
            )
            return map
        }()
        
        var facilitiesGraphicsOverlay: GraphicsOverlay = {
            var facilitiesGraphicsOverlay = GraphicsOverlay()
            let facilitySymbol = PictureMarkerSymbol(image: UIImage(named: "RedMarker")!)
            //PictureMarkerSymbol(image: UIImage(named: "Facility")!)
            // offset symbol in Y to align image properly
            facilitySymbol.offsetY = 21
            // assign renderer on facilities graphics overlay using the picture marker symbol
            facilitiesGraphicsOverlay.renderer = SimpleRenderer(symbol: facilitySymbol)
            return facilitiesGraphicsOverlay
        }()
        
        var barriersGraphicsOverlay: GraphicsOverlay = {
            var barriersGraphicsOverlay = GraphicsOverlay()
            let barrierSymbol = SimpleFillSymbol(style: .diagonalCross, color: .red, outline: nil)
            // set symbol on barrier graphics overlay using renderer
            barriersGraphicsOverlay.renderer = SimpleRenderer(symbol: barrierSymbol)
            return barriersGraphicsOverlay
        }()
        
        var serviceAreaGraphicsOverlay = GraphicsOverlay()
        private var barrierGraphic: Graphic!
        private var serviceAreaTask: ServiceAreaTask!
        private var serviceAreaParameters: ServiceAreaParameters!
        var firstTimeBreak: Int = 3
        var secondTimeBreak: Int = 8
        
        func setServiceArea() async throws {
            self.serviceAreaTask = ServiceAreaTask(url: URL(string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/NetworkAnalysis/SanDiego/NAServer/ServiceArea")!)
            try await getDefaultParameters()
        }
        
        func onTap(point: Point) {
            let graphic = Graphic(geometry: point, symbol: nil)
            self.facilitiesGraphicsOverlay.addGraphic(graphic)
            let bufferedGeometry = GeometryEngine.buffer(around: point, distance: 500)
            //bufferGeometry(point, byDistance: 500)
            let graphic2 = Graphic(geometry: bufferedGeometry, symbol: nil)
            self.barriersGraphicsOverlay.addGraphic(graphic2)
            //                  } else {
            //                      // barriers selected
            //                      let bufferedGeometry = AGSGeometryEngine.bufferGeometry(mapPoint, byDistance: 500)
            //                      let graphic = AGSGraphic(geometry: bufferedGeometry, symbol: nil, attributes: nil)
            //                      self.barriersGraphicsOverlay.graphics.add(graphic)
        }
        
        func serviceArea() async throws {
            try await setServiceArea()
            
            // remove previously added service areas
            serviceAreaGraphicsOverlay.removeAllGraphics()
            
            let facilitiesGraphics = facilitiesGraphicsOverlay.graphics
            //
            //               // check if at least a single facility is added
            //               guard !facilitiesGraphics.isEmpty else {
            //                   presentAlert(message: "At least one facility is required")
            //                   return
            //               }
            
            // add facilities
            var facilities = [ServiceAreaFacility]()
            
            // for each graphic in facilities graphicsOverlay add a facility to the parameters
            for graphic in facilitiesGraphics {
                let point = graphic.geometry as! Point
                let facility = ServiceAreaFacility(point: point)
                facilities.append(facility)
            }
            self.serviceAreaParameters.setFacilities(facilities)
            
            // add barriers
            var barriers = [PolygonBarrier]()
            
            // for each graphic in barrier graphicsOverlay add a barrier to the parameters
            for graphic in barriersGraphicsOverlay.graphics {
                let polygon = graphic.geometry as! Polygon
                let barrier = PolygonBarrier(polygon: polygon)
                barriers.append(barrier)
            }
            serviceAreaParameters.setPolygonBarriers(barriers)
            serviceAreaParameters.addDefaultImpedanceCutoffs([Double(firstTimeBreak), Double(secondTimeBreak)])
            serviceAreaParameters.geometryAtOverlap = .dissolve
            print("here")
            let result = try await serviceAreaTask.solveServiceArea(using: serviceAreaParameters)
            
            let polygons = result.resultPolygons(forFacilityAtIndex: 0)
            for i in polygons.indices {
                let polygon = polygons[i]
                let fillSymbol = self.serviceAreaSymbol(for: i)
                let graphic = Graphic(geometry: polygon.geometry, symbol: fillSymbol)
                self.serviceAreaGraphicsOverlay.addGraphic(graphic)
            }
        }
        
        private func getDefaultParameters() async throws {
            // get default parameters
            serviceAreaParameters = try await self.serviceAreaTask.makeDefaultParameters()
        }
        
        private func serviceAreaSymbol(for index: Int) -> Symbol {
            // fill symbol for service area
            var fillSymbol: SimpleFillSymbol
            
            if index == 0 {
                let lineSymbol = SimpleLineSymbol(style: .solid, color: UIColor(red: 0.4, green: 0.4, blue: 0, alpha: 0.3), width: 2)
                fillSymbol = SimpleFillSymbol(style: .solid, color: UIColor(red: 0.8, green: 0.8, blue: 0, alpha: 0.3), outline: lineSymbol)
            } else {
                let lineSymbol = SimpleLineSymbol(style: .solid, color: UIColor(red: 0, green: 0.4, blue: 0, alpha: 0.3), width: 2)
                fillSymbol = SimpleFillSymbol(style: .solid, color: UIColor(red: 0, green: 0.8, blue: 0, alpha: 0.3), outline: lineSymbol)
            }
            
            return fillSymbol
        }
    }
}

private extension URL {
    static let serviceArea = URL(string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/NetworkAnalysis/SanDiego/NAServer/ServiceArea")!
}

#Preview {
    ShowServiceAreaView()
}
