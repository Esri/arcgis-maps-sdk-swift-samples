// Copyright 2025 Esri
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

struct ShowGeodesicSectorAndEllipseView: View {
    /// The data model that helps determine the view.
    @StateObject private var model = Model()
    
    /// Manages the presentation state of the menu.
    @State private var isPresented: Bool = false
    
    var body: some View {
        MapViewReader { mapView in
            MapView(
                map: model.map,
                graphicsOverlays: model.graphicOverlays
            )
            .onSingleTapGesture { _, tapPoint in
                model.center = tapPoint
            }
            .task(id: model.center) {
                guard let center = model.center else { return }
                await mapView.setViewpoint(
                    Viewpoint(center: center, scale: 1e7)
                )
            }
            .toolbar {
                // The menu which holds the options that change the ellipse and sector.
                ToolbarItemGroup(placement: .bottomBar) {
                    Button("Settings") {
                        isPresented = true
                    }
                    .disabled(model.center == nil)
                    .popover(isPresented: $isPresented) {
                        Form {
                            let format = FloatingPointFormatStyle<Double>()
                                .precision(.fractionLength(0))
                                .grouping(.never)
                            
                            LabeledContent(
                                "Axis Direction",
                                value: model.axisDirection,
                                format: format
                            )
                            
                            Slider(
                                value: $model.axisDirection,
                                in: 0...365,
                                label: {
                                    Text("Axis Direction")
                                },
                                minimumValueLabel: {
                                    Text("0")
                                },
                                maximumValueLabel: {
                                    Text("365")
                                }
                            ).onChange(of: model.axisDirection) {
                                model.refreshSector()
                            }
                            .listRowSeparator(
                                .hidden,
                                edges: [.top]
                            )
                            
                            LabeledContent(
                                "Max Point Count",
                                value: Double(model.maxPointCount),
                                format: format
                            )
                            
                            Slider(
                                value: Binding(
                                    get: {
                                        Double(model.maxPointCount)
                                    },
                                    set: {
                                        model.maxPointCount = Int($0)
                                        model.refreshSector()
                                    }
                                ),
                                in: 0...1_000,
                                step: 1
                            )
                            .listRowSeparator(
                                .hidden,
                                edges: [.top]
                            )
                            
                            LabeledContent(
                                "Max Segment Length",
                                value: model.maxSegmentLength,
                                format: format
                            )
                            
                            Slider(
                                value: $model.maxSegmentLength,
                                in: 1...1_000,
                                label: {
                                    Text("Max Segment Length")
                                },
                                minimumValueLabel: {
                                    Text("1")
                                },
                                maximumValueLabel: {
                                    Text("1000")
                                }
                            ).onChange(of: model.maxSegmentLength) {
                                model.refreshSector()
                            }
                            .listRowSeparator(.hidden, edges: [.top])
                            
                            Picker("Geometry Type", selection: $model.geometryType) {
                                ForEach(GeometryType.allCases, id: \.self) { geometryType in
                                    Text(geometryType.label)
                                }
                            }
                            .onChange(of: model.geometryType) {
                                model.refreshSector()
                            }
                            
                            LabeledContent(
                                "Sector Angle",
                                value: model.sectorAngle,
                                format: format
                            )
                            
                            Slider(
                                value: $model.sectorAngle,
                                in: 0...365,
                                label: {
                                    Text("Sector Angle")
                                },
                                minimumValueLabel: {
                                    Text("0")
                                },
                                maximumValueLabel: {
                                    Text("365")
                                }
                            ).onChange(of: model.sectorAngle) {
                                model.refreshSector()
                            }
                            .listRowSeparator(
                                .hidden,
                                edges: [.top]
                            )
                            
                            LabeledContent(
                                "Semi Axis 1 Length",
                                value: model.semiAxis1Length,
                                format: format
                            )
                            
                            Slider(
                                value: $model.semiAxis1Length,
                                in: 0...1_000,
                                label: {
                                    Text("Semi Axis 1 Length")
                                },
                                minimumValueLabel: {
                                    Text("0")
                                },
                                maximumValueLabel: {
                                    Text("1000")
                                }
                            ).onChange(of: model.semiAxis1Length) {
                                model.refreshSector()
                            }
                            .listRowSeparator(
                                .hidden,
                                edges: [.top]
                            )
                            
                            LabeledContent(
                                "Semi Axis 2 Length",
                                value: model.semiAxis2Length,
                                format: format
                            )
                            Slider(
                                value: $model.semiAxis2Length,
                                in: 0...1_000,
                                label: {
                                    Text("Semi Axis 2 Length")
                                },
                                minimumValueLabel: {
                                    Text("0")
                                },
                                maximumValueLabel: {
                                    Text("1000")
                                }
                            ).onChange(of: model.semiAxis2Length) {
                                model.refreshSector()
                            }
                            .listRowSeparator(
                                .hidden,
                                edges: [.top]
                            )
                        }
                        .presentationDetents([.medium])
                    }
                }
            }
        }
    }
}

private extension ShowGeodesicSectorAndEllipseView {
    /// Custom data type so that Geometry options can be displayed in the menu.
    enum GeometryType: CaseIterable {
        case point, polyline, polygon
        
        var label: String {
            switch self {
            case .point: "Point"
            case .polyline: "Polyline"
            case .polygon: "Polygon"
            }
        }
    }
    
    /// A view model that encapsulates logic and state for rendering a geodesic sector and ellipse.
    /// Handles user-configured parameters and updates overlays when those parameters change.
    @MainActor
    class Model: ObservableObject {
        /// The map that will be displayed in the map view.
        let map = Map(basemapStyle: .arcGISTopographic)
        
        /// The map point selected by the user when tapping on the map.
        @Published var center: Point? {
            didSet {
                guard let center = center else { return }
                updateSector(center: center)
            }
        }
        
        var graphicOverlays: [GraphicsOverlay] {
            return [ellipseGraphicOverlay, sectorGraphicOverlay]
        }
        
        /// The graphics overlay that will be displayed on the map view.
        /// This will hold the graphics that show the ellipse path.
        private let ellipseGraphicOverlay = GraphicsOverlay()
        
        /// The graphics overlay that will be displayed on the map view.
        /// This will display a highlighted section of the ellipse path.
        private let sectorGraphicOverlay = GraphicsOverlay()
        
        /// The direction (in degrees) of the ellipse's major axis.
        @Published var axisDirection: Double = 45
        /// Controls the complexity of the geometries and the approximation of the ellipse curve.
        @Published var maxSegmentLength: Double = 1
        /// Changes the sectors shape.
        @Published var sectorAngle: Double = 90
        /// Controls the complexity of the geometries and the approximation of the ellipse curve.
        @Published var maxPointCount: Int = 1_000
        /// Changes the length of ellipse shape on one axis.
        @Published var semiAxis1Length: Double = 200
        /// Changes the length of ellipse shape on one axis.
        @Published var semiAxis2Length: Double = 100
        /// Changes the geometry type which the sector is rendered.
        @Published var geometryType: GeometryType = .polygon
        /// Changes the direction of the sector.
        @Published var startDirection: Double = 45
        
        func refreshSector() {
            guard let center = center else { return }
            updateSector(center: center)
        }
        
        private func updateSector(center: Point) {
            ellipseGraphicOverlay.removeAllGraphics()
            sectorGraphicOverlay.removeAllGraphics()
            updateEllipse(center: center)
            setupSector(center: center, geometryType: geometryType)
        }
        
        private func setupSector(center: Point, geometryType: GeometryType) {
            switch geometryType {
            case .point:
                // Generate sector as a multipoint (symbols).
                var parameters = GeodesicSectorParameters<Multipoint>()
                fillSectorParams(&parameters, center: center)
                if let geometry = GeometryEngine.geodesicSector(parameters: parameters) {
                    addSectorGraphic(
                        geometry: geometry,
                        symbol: SimpleMarkerSymbol(
                            style: .circle,
                            color: .green,
                            size: 2
                        )
                    )
                }
            case .polyline:
                // Generate sector as a polyline (outlined arc).
                var parameters = GeodesicSectorParameters<Polyline>()
                fillSectorParams(&parameters, center: center)
                if let geometry = GeometryEngine.geodesicSector(parameters: parameters) {
                    addSectorGraphic(
                        geometry: geometry,
                        symbol: SimpleLineSymbol(
                            style: .solid,
                            color: .green,
                            width: 2
                        )
                    )
                }
            case .polygon:
                // Generate sector as a filled polygon.
                var parameters = GeodesicSectorParameters<ArcGIS.Polygon>()
                fillSectorParams(&parameters, center: center)
                if let geometry = GeometryEngine.geodesicSector(parameters: parameters) {
                    addSectorGraphic(
                        geometry: geometry,
                        symbol: SimpleFillSymbol(
                            style: .solid,
                            color: .green
                        )
                    )
                }
            }
        }
        
        /// Populates a `GeodesicSectorParameters<T>` instance with current user-defined values.
        /// - Parameter parameters: A reference to the parameter struct that will be filled.
        /// - Parameter center: The center point for the sector/ellipse.
        private func fillSectorParams<T>(_ parameters: inout GeodesicSectorParameters<T>, center: Point) {
            parameters.center = center
            parameters.axisDirection = axisDirection
            parameters.maxPointCount = maxPointCount
            parameters.maxSegmentLength = maxSegmentLength
            parameters.sectorAngle = sectorAngle
            parameters.semiAxis1Length = semiAxis1Length
            parameters.semiAxis2Length = semiAxis2Length
            parameters.startDirection = startDirection
            parameters.linearUnit = .miles
        }
        
        /// Adds a sector graphic to the overlay and applies the appropriate renderer.
        private func addSectorGraphic(geometry: Geometry, symbol: Symbol) {
            let sectorGraphic = Graphic(geometry: geometry, symbol: symbol)
            sectorGraphicOverlay.renderer = SimpleRenderer(symbol: symbol)
            sectorGraphicOverlay.addGraphic(sectorGraphic)
        }
        
        /// Generates and adds a geodesic ellipse graphic based on the current settings and center point.
        private func updateEllipse(center: Point) {
            let parameters = GeodesicEllipseParameters<ArcGIS.Polygon>(
                axisDirection: axisDirection,
                center: center,
                linearUnit: .miles,
                maxPointCount: maxPointCount,
                maxSegmentLength: maxSegmentLength,
                semiAxis1Length: semiAxis1Length,
                semiAxis2Length: semiAxis2Length
            )
            let ellipseGeometry = GeometryEngine.geodesicEllipse(parameters: parameters)
            let graphic = Graphic(
                geometry: ellipseGeometry,
                symbol: SimpleLineSymbol(
                    style: .dash,
                    color: .red,
                    width: 2
                )
            )
            ellipseGraphicOverlay.addGraphic(graphic)
        }
    }
}

#Preview {
    ShowGeodesicSectorAndEllipseView()
}
