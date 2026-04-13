// Copyright 2026 Esri
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

struct ShowLineOfSightAnalysisInMapView: View {
    /// The view model for the sample.
    @State private var model = Model()
    /// Information about the line of sight analysis results.
    @State private var lineOfSightInfos: [LineOfSightInfo] = []
    /// A Boolean value indicating whether the info view is showing.
    @State private var isShowingInfoView = false
    /// A Boolean value indicating whether the obstructed line of sight graphics are showing.
    @State private var isShowingObstructed = true
    /// The error shown in the error alert.
    @State private var error: (any Error)?
    
    var body: some View {
        MapView(map: model.map, graphicsOverlays: model.graphicOverlays)
            .overlay(alignment: .top) {
                Text("Raster data copyright Scottish Government and SEPA (2014)")
                    .font(.caption)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(.thinMaterial, ignoresSafeAreaEdges: .horizontal)
            }
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button("Info") {
                        isShowingInfoView.toggle()
                    }
                    .popover(isPresented: $isShowingInfoView) {
                        List(lineOfSightInfos, id: \.self) { info in
                            LineOfSightInfoView(info: info)
                        }
                        .presentationDetents([.fraction(0.5)])
                        .frame(idealWidth: 320, idealHeight: 380)
                    }
                    
                    Spacer()
                    
                    Menu("Settings", systemImage: "gear") {
                        Toggle("Show Obstructed", isOn: $isShowingObstructed)
                            .onChange(of: isShowingObstructed) {
                                model.setObstructedVisibility(isVisible: isShowingObstructed)
                            }
                    }
                }
            }
            .task {
                do {
                    lineOfSightInfos = try await model.evaluateLinesOfSight()
                } catch {
                    self.error = error
                }
            }
            .errorAlert(presentingError: $error)
    }
}

// MARK: Model

/// The view model for this sample.
@MainActor
@Observable
private final class Model {
    /// A map with a dark hillshade basemap initially centered on the Isle of Arran, Scotland.
    let map: Map = {
        let map = Map(basemapStyle: .arcGISHillshadeDark)
        let initialExtent = Envelope(xRange: -584770 ... -570630, yRange: 7471510 ... 7494260)
        map.initialViewpoint = Viewpoint(boundingGeometry: initialExtent)
        return map
    }()
    
    /// The overlays containing the graphics to display on the map.
    var graphicOverlays: [GraphicsOverlay] {
        return [lineOfSightGraphicsOverlay, positionGraphicsOverlay]
    }
    
    /// The overlay containing the line of sight analysis result graphics.
    private let lineOfSightGraphicsOverlay = GraphicsOverlay()
    
    /// The overlay containing the target and observer position graphics.
    private let positionGraphicsOverlay = GraphicsOverlay()
    
    /// The height of the target and observer position points.
    nonisolated private static let positionHeight = 5.0
    
    /// The target observer's location on the map.
    private let targetPoint = Point(
        x: -577955.365,
        y: 7484288.220,
        z: positionHeight,
        spatialReference: .webMercator
    )
    
    /// An observer of a line of sight analysis.
    private struct Observer {
        /// The observer's location on the map in Web Mercator.
        let point: Point
        /// The observer's symbol for its graphic.
        let symbol: SimpleMarkerSymbol
        
        init(x: Double, y: Double, color: UIColor) {
            point = Point(x: x, y: y, z: positionHeight, spatialReference: .webMercator)
            symbol = SimpleMarkerSymbol(style: .triangle, color: color, size: 15)
        }
    }
    
    /// The observers to evaluate lines of sight for.
    private let observers = [
        Observer(x: -580893.546, y: 7489102.890, color: .green),
        Observer(x: -583446.004, y: 7483567.462, color: .white),
        Observer(x: -577665.236, y: 7490792.908, color: .orange),
        Observer(x: -576452.981, y: 7487071.388, color: .yellow),
        Observer(x: -576650.067, y: 7481479.772, color: .purple),
        Observer(x: -571683.896, y: 7492017.864, color: .blue)
    ]
    
    init() {
        // Creates graphics to display the target and observer positions on the map.
        let beaconImage = UIImage(named: "beacon")!
        let beaconSymbol = PictureMarkerSymbol(image: beaconImage)
        beaconSymbol.width = 22
        beaconSymbol.height = 22
        
        let targetGraphic = Graphic(geometry: targetPoint, symbol: beaconSymbol)
        positionGraphicsOverlay.addGraphic(targetGraphic)
        
        let observerGraphics = observers.map { Graphic(geometry: $0.point, symbol: $0.symbol) }
        positionGraphicsOverlay.addGraphics(observerGraphics)
    }
    
    /// Runs a line of sight analysis.
    /// - Returns: Information about the line of sight results.
    func evaluateLinesOfSight() async throws -> [LineOfSightInfo] {
        // Creates a continuous field using a TIF file containing elevation data.
        let elevationField = try await ContinuousField.field(fromFilesAt: [.arranTIF], bandIndex: 0)
        
        // Creates line of sight parameters with target and observer positions.
        let parameters = LineOfSightParameters()
        let targetPosition = LineOfSightPosition(position: targetPoint, heightOrigin: .relative)
        let observerPositions = observers.map { observer in
            LineOfSightPosition(position: observer.point, heightOrigin: .relative)
        }
        parameters.observerTargetPairs = ObserverTargetPairs(
            observers: observerPositions,
            targets: [targetPosition],
        )
        
        // Creates and evaluates a line of sight function to get the lines of sight.
        let lineOfSightFunction = LineOfSightFunction(
            elevation: elevationField,
            parameters: parameters,
        )
        let lineOfSightResults = try await lineOfSightFunction.evaluate()
        
        // Creates and adds graphics for the results to show the lines of sight on the map.
        let lineOfSightGraphics = makeLineOfSightGraphics(lineOfSightResults)
        lineOfSightGraphicsOverlay.addGraphics(lineOfSightGraphics)
        
        return zip(lineOfSightResults, observers).map { lineOfSight, observer in
            LineOfSightInfo(lineOfSight, observerSymbol: observer.symbol)
        }
    }
    
    /// Sets the visibility of the obstructed line of sight graphics.
    /// - Parameter isVisible: A Boolean value indicating whether the graphics should be visible.
    func setObstructedVisibility(isVisible: Bool) {
        for graphic in lineOfSightGraphicsOverlay.graphics {
            guard let targetVisibility = graphic.attributes["targetVisibility"] as? Float,
                  targetVisibility != 1 else {
                continue
            }
            graphic.isVisible = isVisible
        }
    }
    
    /// Creates graphics for displaying line of sight visibilities.
    /// - Parameter linesOfSight: The lines of sight results to create graphics for.
    private func makeLineOfSightGraphics(_ linesOfSight: [LineOfSight]) -> [Graphic] {
        let visibleLineSymbol = SimpleLineSymbol(color: .green, width: 2)
        let notVisibleLineSymbol = SimpleLineSymbol(style: .longDash, color: .gray)
        return linesOfSight.flatMap { linesOfSight in
            let visibleLineGraphic = Graphic(
                geometry: linesOfSight.visibleLine,
                attributes: ["targetVisibility": linesOfSight.targetVisibility],
                symbol: visibleLineSymbol
            )
            let notVisibleLineGraphic = Graphic(
                geometry: linesOfSight.notVisibleLine,
                attributes: ["targetVisibility": linesOfSight.targetVisibility],
                symbol: notVisibleLineSymbol
            )
            return [visibleLineGraphic, notVisibleLineGraphic]
        }
    }
}

// MARK: - LineOfSightInfo

/// Information about a line of sight analysis result.
private struct LineOfSightInfo: Hashable {
    /// The description of the line of sight result.
    let description: String
    /// The symbol of the line of sight's observer.
    let observerSymbol: Symbol
    
    init(_ lineOfSight: LineOfSight, observerSymbol: Symbol) {
        if let error = lineOfSight.error {
            // Uses the error as the description if line of sight could not be evaluated.
            let illegalStateError = lineOfSight.error as? IllegalStateError
            description = illegalStateError?.details ?? error.localizedDescription
        } else {
            // Calculates the visible distance from the observer in meters.
            let visibleLength = if let visibleLine = lineOfSight.visibleLine {
                GeometryEngine.geodeticLength(of: visibleLine, lengthUnit: nil, curveType: .geodesic)
            } else {
                0.0
            }
            let formattedVisibleLength = visibleLength.formatted(.number.rounded(increment: 1))
            
            // Uses `notVisibleLine` to determine if the target is visible from the observer.
            description = if lineOfSight.notVisibleLine == nil {
                "Target visible from observer after \(formattedVisibleLength) m."
            } else {
                "Target obstructed from observer after \(formattedVisibleLength) m."
            }
        }
        
        self.observerSymbol = observerSymbol
    }
}

/// A view that displays information about a line of sight analysis result.
private struct LineOfSightInfoView: View {
    /// The line of sight information to display.
    let info: LineOfSightInfo
    
    /// The display scale of this environment.
    @Environment(\.displayScale) private var displayScale
    
    /// An image of the observer's symbol.
    @State private var observerSymbolSwatch: UIImage?
    
    var body: some View {
        Label {
            Text(info.description)
        } icon: {
            if let observerSymbolSwatch {
                Image(uiImage: observerSymbolSwatch)
            } else {
                Image(systemName: "xmark")
            }
        }
        .task(id: info.observerSymbol) {
            observerSymbolSwatch = try? await info.observerSymbol.makeSwatch(
                scale: displayScale,
                size: CGSize(width: 24, height: 24)
            )
        }
    }
}

// MARK: - Extensions

private extension URL {
    /// A URL to a local GeoTIFF file containing elevation data of the Isle of Arran, Scotland.
    static var arranTIF: URL {
        Bundle.main.url(forResource: "arran", withExtension: "tif", subdirectory: "arran")!
    }
}
