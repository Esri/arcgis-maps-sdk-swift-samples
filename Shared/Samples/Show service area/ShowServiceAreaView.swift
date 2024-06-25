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
    
    /// The point on the map where the user tapped.
    @State private var tapLocation: Point?
    
    @State private var firstTimeBreak: Double = 3
    @State private var secondTimeBreak: Double = 8
    
    var selections = ["Facilities", "Barriers"]

//    @State private var timeElement = "Time"
//    
    @State private var selected = "Facilities"
    
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
            .onSingleTapGesture { _, point in
                tapLocation = point
                model.onTap(point: point, selection: self.selected)
            }
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Picker("Mode", selection: $selected) {
                        ForEach(selections, id: \.self) {
                            Text($0)
                        }
                    }
                    .pickerStyle(.segmented)
                    Menu(content: {
                        Slider(value: $firstTimeBreak,
                               in: 1...10,
                               step: 1,
                               label: { Text("First Break: \(Int(firstTimeBreak))") }
                        )
                        .padding(.horizontal, 4)
                        .padding(.vertical, 4)
                        
                        Slider(value: $secondTimeBreak,
                               in: 1...10,
                               step: 1,
                               label: { Text("Second Break: \(Int(secondTimeBreak))") }
                        )
                        .padding(.horizontal, 4)
                        .padding(.vertical, 4)
                    }, label: { Text("Time Break") })
                    Button("Facs") {
                        Task {
                            do {
                                try await model.serviceArea()
                            } catch {
                                print(error.localizedDescription)
                            }
                        }
                    }
                    Button("Clear") {
                        model.removeAllGraphics()
                    }
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
                center: Point(
                    x: -13041154,
                    y: 3858170,
                    spatialReference: .webMercator
                ),
                scale: 60000
            )
            return map
        }()
        
        var facilitiesGraphicsOverlay: GraphicsOverlay = {
            var facilitiesGraphicsOverlay = GraphicsOverlay()
            let facilitySymbol = PictureMarkerSymbol(image: UIImage(named: "PinBlueStar")!)
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
            serviceAreaTask = ServiceAreaTask(url: .serviceArea)
            serviceAreaParameters = try await serviceAreaTask.makeDefaultParameters()
        }
        
        func onTap(point: Point, selection: String) {
            if selection == "Facilities" {
                // facilities selected
                let graphic = Graphic(geometry: point, symbol: nil)
                self.facilitiesGraphicsOverlay.addGraphic(graphic)
            } else {
                // barriers selected
                let bufferedGeometry = GeometryEngine.buffer(around: point, distance: 500)
                let graphic = Graphic(geometry: bufferedGeometry, symbol: nil)
                self.barriersGraphicsOverlay.addGraphic(graphic)
            }
        }
        
        func serviceArea() async throws {
            try await setServiceArea()
            
            // remove previously added service areas
            serviceAreaGraphicsOverlay.removeAllGraphics()
            let facilitiesGraphics = facilitiesGraphicsOverlay.graphics
            // check if at least a single facility is added
            // add facilities
            var facilities = [ServiceAreaFacility]()
            // for each graphic in facilities graphicsOverlay add a facility to the parameters
            for graphic in facilitiesGraphics {
                let point = graphic.geometry as! Point
                let facility = ServiceAreaFacility(point: point)
                facilities.append(facility)
            }
            serviceAreaParameters.setFacilities(facilities)
            // add barriers
            var barriers = [PolygonBarrier]()
            
            // for each graphic in barrier graphicsOverlay add a barrier to the parameters
            for graphic in barriersGraphicsOverlay.graphics {
                let polygon = graphic.geometry as! Polygon
                let barrier = PolygonBarrier(polygon: polygon)
                barriers.append(barrier)
            }
            serviceAreaParameters.setPolygonBarriers(barriers)
            serviceAreaParameters.removeAllDefaultImpedanceCutoffs()
            serviceAreaParameters.addDefaultImpedanceCutoffs([Double(firstTimeBreak), Double(secondTimeBreak)])
            //            serviceAreaParameters.removeDefaultImpedanceCutoff(5.0)
            serviceAreaParameters.geometryAtOverlap = .dissolve
            let result = try await serviceAreaTask.solveServiceArea(using: serviceAreaParameters)
            let polygons = result.resultPolygons(forFacilityAtIndex: 0)
            for i in polygons.indices {
                let polygon = polygons[i]
                let fillSymbol = serviceAreaSymbol(for: i)
                let graphic = Graphic(geometry: polygon.geometry, symbol: fillSymbol)
                serviceAreaGraphicsOverlay.addGraphic(graphic)
            }
        }
        
        func removeAllGraphics() {
            serviceAreaGraphicsOverlay.removeAllGraphics()
            facilitiesGraphicsOverlay.removeAllGraphics()
            barriersGraphicsOverlay.removeAllGraphics()
        }
        
        
        
        private func serviceAreaSymbol(for index: Int) -> Symbol {
            // fill symbol for service area
            var fillSymbol: SimpleFillSymbol
            
            if index == 0 {
                let lineSymbol = SimpleLineSymbol(
                    style: .solid,
                    color: UIColor(
                        red: 0.4,
                        green: 0.4,
                        blue: 0,
                        alpha: 0.3
                    ),
                    width: 2
                )
                fillSymbol = SimpleFillSymbol(
                    style: .solid,
                    color: UIColor(
                        red: 0.8,
                        green: 0.8,
                        blue: 0,
                        alpha: 0.3
                    ),
                    outline: lineSymbol
                )
            } else {
                let lineSymbol = SimpleLineSymbol(
                    style: .solid,
                    color: UIColor(
                        red: 0,
                        green: 0.4,
                        blue: 0,
                        alpha: 0.3
                    ),
                    width: 2
                )
                fillSymbol = SimpleFillSymbol(
                    style: .solid,
                    color: UIColor(
                        red: 0,
                        green: 0.8,
                        blue: 0,
                        alpha: 0.3
                    ),
                    outline: lineSymbol
                )
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
