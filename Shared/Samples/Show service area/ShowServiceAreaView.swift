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

struct ShowServiceAreaView: View {
    /// The currently selected graphic type.
    /// Used to track whether to add facilities or barriers to the map.
    @State private var selectedGraphicType: GraphicType = .facilities
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    /// The data model for the sample.
    @StateObject private var model = Model()
    
    var body: some View {
        MapView(map: model.map, graphicsOverlays: model.graphicsOverlays)
            .onSingleTapGesture { _, point in
                model.placeGraphicOnTapLocation(at: point, with: selectedGraphicType)
            }
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Picker("Mode", selection: $selectedGraphicType) {
                        ForEach(GraphicType.allCases, id: \.self) {
                            Text($0.label)
                        }
                    }
                    .pickerStyle(.segmented)
                    Spacer()
                    Menu {
                        Stepper("Second: \(model.secondTimeBreak)", value: $model.secondTimeBreak, in: 1...15)
                        Stepper("First: \(model.firstTimeBreak)", value: $model.firstTimeBreak, in: 1...15)
                    } label: {
                        Label("Time", systemImage: "gear")
                    }
                    Spacer()
                    Button("Service Area") {
                        Task {
                            do {
                                try await model.showServiceArea(timeBreaks: [model.firstTimeBreak, model.secondTimeBreak])
                            } catch {
                                self.error = error
                            }
                        }
                    }
                    Spacer()
                    Button("Clear", systemImage: "trash.fill") {
                        model.removeAllGraphics()
                    }
                }
            }
            .errorAlert(presentingError: $error)
    }
}

private enum GraphicType: Equatable, CaseIterable {
    case facilities, barriers
    
    /// The string representation of this graphic type.
    var label: String {
        switch self {
        case .barriers: "Barriers"
        case .facilities: "Facilities"
        }
    }
}

private extension ShowServiceAreaView {
    class Model: ObservableObject {
        /// A map with terrain style centered over San Diego.
        let map: Map = {
            let map = Map(basemapStyle: .arcGISTerrain)
            map.initialViewpoint = Viewpoint(
                center: Point(
                    x: -13041154,
                    y: 3858170,
                    spatialReference: .webMercator
                ),
                scale: 60_000
            )
            return map
        }()
        
        let facilitiesGraphicsOverlay: GraphicsOverlay = {
            let facilitiesGraphicsOverlay = GraphicsOverlay()
            let facilitySymbol = PictureMarkerSymbol(image: UIImage(named: "PinBlueStar")!)
            // Offsets symbol in Y to align image properly.
            facilitySymbol.offsetY = 21
            // Assigns renderer on facilities graphics overlay using the picture marker symbol.
            facilitiesGraphicsOverlay.renderer = SimpleRenderer(symbol: facilitySymbol)
            return facilitiesGraphicsOverlay
        }()
        
        let barriersGraphicsOverlay: GraphicsOverlay = {
            let barriersGraphicsOverlay = GraphicsOverlay()
            let barrierSymbol = SimpleFillSymbol(style: .diagonalCross, color: .red, outline: nil)
            // Sets symbol on barrier graphics overlay using renderer.
            barriersGraphicsOverlay.renderer = SimpleRenderer(symbol: barrierSymbol)
            return barriersGraphicsOverlay
        }()
        
        let serviceAreaGraphicsOverlay = GraphicsOverlay()
        
        /// The graphics overlays used by this model.
        var graphicsOverlays: [GraphicsOverlay] {
            [facilitiesGraphicsOverlay, barriersGraphicsOverlay, serviceAreaGraphicsOverlay]
        }
        
        private let serviceAreaTask = ServiceAreaTask(url: .serviceArea)
        
        private var serviceAreaParameters: ServiceAreaParameters!
        
        /// First time break property set in first slider.
        @Published var firstTimeBreak: Double = 3
        
        /// Second time break property set in second slider.
        @Published var secondTimeBreak: Double = 8
        
        /// On user tapping on screen, depending on the selection type, it sets
        /// either the barrier or facilities overlays on the map at the tap point.
        /// - Parameters:
        ///   - point: The tap location.
        ///   - selection: The type of graphic to be added to the view.
        func placeGraphicOnTapLocation(at point: Point, with selection: GraphicType) {
            switch selection {
            case .facilities:
                let graphic = Graphic(geometry: point, symbol: nil)
                facilitiesGraphicsOverlay.addGraphic(graphic)
            case .barriers:
                let bufferedGeometry = GeometryEngine.buffer(around: point, distance: 500)
                let graphic = Graphic(geometry: bufferedGeometry, symbol: nil)
                barriersGraphicsOverlay.addGraphic(graphic)
            }
        }
        
        /// Gets the service area data and then renders the service area on the map.
        func showServiceArea(timeBreaks: [Double]) async throws {
            if serviceAreaParameters == nil {
                serviceAreaParameters = try await serviceAreaTask.makeDefaultParameters()
                serviceAreaParameters.geometryAtOverlap = .dissolve
            }
            serviceAreaGraphicsOverlay.removeAllGraphics()
            // Add the graphics to the overlays with their respective geometry types.
            serviceAreaParameters.setFacilities(
                facilitiesGraphicsOverlay.graphics.lazy.map { .init(point: $0.geometry as! Point) }
            )
            serviceAreaParameters.setPolygonBarriers(
                barriersGraphicsOverlay.graphics.lazy.map { .init(polygon: $0.geometry as! ArcGIS.Polygon) }
            )
            serviceAreaParameters.removeAllDefaultImpedanceCutoffs()
            serviceAreaParameters.addDefaultImpedanceCutoffs(timeBreaks)
            try await renderServiceAreaPolygons()
        }
        
        /// Asynchronously uses the service area task to solve for the service area using the parameters and then iterates through resulting
        /// polygons and creates a graphic which is added to the overlay for rendering.
        private func renderServiceAreaPolygons() async throws {
            let result = try await serviceAreaTask.solveServiceArea(using: serviceAreaParameters)
            let polygons = result.resultPolygons(forFacilityAtIndex: 0)
            for (offset, polygon) in polygons.enumerated() {
                let fillSymbol = makeServiceAreaSymbol(isFirst: offset == .zero)
                let graphic = Graphic(geometry: polygon.geometry, symbol: fillSymbol)
                serviceAreaGraphicsOverlay.addGraphic(graphic)
            }
        }
        
        /// Resets the graphics, removes the barriers, facilities and service area.
        func removeAllGraphics() {
            serviceAreaGraphicsOverlay.removeAllGraphics()
            facilitiesGraphicsOverlay.removeAllGraphics()
            barriersGraphicsOverlay.removeAllGraphics()
        }
        
        /// Sets the symbols drawn on that map for given selection.
        /// - Parameter index: Takes the index to decide how to render.
        /// - Returns: Returns the symbol.
        private func makeServiceAreaSymbol(isFirst: Bool) -> Symbol {
            let lineSymbolColor: UIColor
            let fillSymbolColor: UIColor
            if isFirst {
                lineSymbolColor = UIColor(red: 0.4, green: 0.4, blue: 0, alpha: 0.3)
                fillSymbolColor = UIColor(red: 0.8, green: 0.8, blue: 0, alpha: 0.3)
            } else {
                lineSymbolColor = UIColor(red: 0, green: 0.4, blue: 0, alpha: 0.3)
                fillSymbolColor = UIColor(red: 0, green: 0.8, blue: 0, alpha: 0.3)
            }
            let outline = SimpleLineSymbol(style: .solid, color: lineSymbolColor, width: 2)
            return SimpleFillSymbol(style: .solid, color: fillSymbolColor, outline: outline)
        }
    }
}

#Preview {
    ShowServiceAreaView()
}

private extension URL {
    static var serviceArea: URL {
        URL(string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/NetworkAnalysis/SanDiego/NAServer/ServiceArea")!
    }
}
