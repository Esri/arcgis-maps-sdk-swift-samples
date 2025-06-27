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
                    .sheet(isPresented: $isPresented) {
                        SectorSettingsView(model: model)
                            .presentationDetents([.medium])
                        Button("Close") {
                            isPresented = false
                        }
                    }
                }
            }
        }
    }
}

private extension ShowGeodesicSectorAndEllipseView {
    /// Custom data type so that Geometry options can be displayed in the menu.
    enum GeometryType: String, CaseIterable, Identifiable {
        case point, polyline, polygon
        
        var id: String { rawValue }
        
        var label: String {
            rawValue.capitalized
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
                guard let center else { return }
                updateSector()
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
        @Published var axisDirection = Measurement<UnitAngle>(value: 45, unit: .degrees) {
            didSet {
                refreshSector()
            }
        }
        /// Controls the complexity of the geometries and the approximation of the ellipse curve.
        @Published var maxSegmentLength: Double = 1 {
            didSet {
                refreshSector()
            }
        }
        /// Changes the sectors shape.
        @Published var sectorAngle = Measurement<UnitAngle>(value: 90, unit: .degrees) {
            didSet {
                refreshSector()
            }
        }
        /// Controls the complexity of the geometries and the approximation of the ellipse curve.
        @Published var maxPointCount: Double = 1_000 {
            didSet {
                refreshSector()
            }
        }
        /// Changes the length of ellipse shape on one axis.
        @Published var semiAxis1Length: Double = 200 {
            didSet {
                refreshSector()
            }
        }
        /// Changes the length of ellipse shape on one axis.
        @Published var semiAxis2Length: Double = 100 {
            didSet {
                refreshSector()
            }
        }
        /// Changes the geometry type which the sector is rendered.
        @Published var geometryType: GeometryType = .polygon {
            didSet {
                refreshSector()
            }
        }
        /// Changes the direction of the sector.
        @Published var startDirection: Double = 45 {
            didSet {
                refreshSector()
            }
        }
        
        func refreshSector() {
            guard let center else { return }
            updateSector()
        }
        
        private func updateSector() {
            ellipseGraphicOverlay.removeAllGraphics()
            sectorGraphicOverlay.removeAllGraphics()
            updateEllipse()
            setupSector()
        }
        
        private func setupSector() {
            switch geometryType {
            case .point:
                // Generate sector as a multipoint (symbols).
                var parameters = GeodesicSectorParameters<Multipoint>()
                fillSectorParameters(&parameters)
                if let geometry = GeometryEngine.geodesicSector(parameters: parameters) {
                    let symbol = SimpleMarkerSymbol(style: .circle, color: .green, size: 2)
                    addSectorGraphic(geometry: geometry, symbol: symbol)
                }
            case .polyline:
                // Generate sector as a polyline (outlined arc).
                var parameters = GeodesicSectorParameters<Polyline>()
                fillSectorParameters(&parameters)
                if let geometry = GeometryEngine.geodesicSector(parameters: parameters) {
                    let symbol = SimpleLineSymbol(style: .solid, color: .green, width: 2)
                    addSectorGraphic(geometry: geometry, symbol: symbol)
                }
            case .polygon:
                // Generate sector as a filled polygon.
                var parameters = GeodesicSectorParameters<ArcGIS.Polygon>()
                fillSectorParameters(&parameters)
                if let geometry = GeometryEngine.geodesicSector(parameters: parameters) {
                    let symbol = SimpleFillSymbol(style: .solid, color: .green)
                    addSectorGraphic(geometry: geometry, symbol: symbol)
                }
            }
        }
        
        /// Populates a geodesic sector parameters value with current user-defined values.
        /// - Parameter parameters: A reference to the parameter struct that will be filled.
        private func fillSectorParameters<T>(_ parameters: inout GeodesicSectorParameters<T>) {
            parameters.center = center
            parameters.axisDirection = axisDirection.value
            parameters.maxPointCount = Int(maxPointCount.rounded())
            parameters.maxSegmentLength = maxSegmentLength
            parameters.sectorAngle = sectorAngle.value
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
        private func updateEllipse() {
            let parameters = GeodesicEllipseParameters<ArcGIS.Polygon>(
                axisDirection: axisDirection.value,
                center: center,
                linearUnit: .miles,
                maxPointCount: Int(maxPointCount.rounded()),
                maxSegmentLength: maxSegmentLength,
                semiAxis1Length: semiAxis1Length,
                semiAxis2Length: semiAxis2Length
            )
            let geometry = GeometryEngine.geodesicEllipse(parameters: parameters)
            let symbol = SimpleLineSymbol(style: .dash, color: .red, width: 2)
            let graphic = Graphic(geometry: geometry, symbol: symbol)
            ellipseGraphicOverlay.addGraphic(graphic)
        }
    }
    
    struct SectorSettingsView: View {
        @ObservedObject var model: ShowGeodesicSectorAndEllipseView.Model
        @Environment(\.dismiss) var dismiss
        
        var body: some View {
            Form {
                let format = FloatingPointFormatStyle<Double>()
                    .precision(.fractionLength(0))
                    .grouping(.never)
                
                let directionFormat = Measurement<UnitAngle>.FormatStyle(
                    width: .narrow,
                    numberFormatStyle: .number.precision(.fractionLength(0))
                )
                
                LabeledContent(
                    "Axis Direction",
                    value: model.axisDirection,
                    format: directionFormat
                )
                let axisDirectionRange = 0.0...360.0
                Slider(
                    value: $model.axisDirection.value,
                    in: axisDirectionRange
                ) {
                    Text("Axis Direction")
                } minimumValueLabel: {
                    Text(
                        Measurement<UnitAngle>(
                            value: axisDirectionRange.lowerBound,
                            unit: .degrees
                        ),
                        format: directionFormat
                    )
                } maximumValueLabel: {
                    Text(
                        Measurement<UnitAngle>(
                            value: axisDirectionRange.upperBound,
                            unit: .degrees
                        ),
                        format: directionFormat
                    )
                }
                .listRowSeparator(.hidden, edges: .top)
                
                LabeledContent(
                    "Max Point Count",
                    value: model.maxPointCount,
                    format: format
                )
                
                Slider(
                    value: $model.maxPointCount,
                    in: 1...1_000,
                    step: 1
                )
                .listRowSeparator(.hidden, edges: .top)
                
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
                )
                .listRowSeparator(.hidden, edges: .top)
                
                Picker("Geometry Type", selection: $model.geometryType) {
                    ForEach(GeometryType.allCases, id: \.self) { geometryType in
                        Text(geometryType.label)
                    }
                }
                LabeledContent(
                    "Sector Angle",
                    value: model.sectorAngle,
                    format: directionFormat
                )
                let sectorAngleRange = 0.0...360.0
                Slider(
                    value: $model.sectorAngle.value,
                    in: sectorAngleRange
                ) {
                    Text("Sector Angle")
                } minimumValueLabel: {
                    Text(
                        Measurement<UnitAngle>(
                            value: sectorAngleRange.lowerBound,
                            unit: .degrees
                        ),
                        format: directionFormat
                    )
                } maximumValueLabel: {
                    Text(
                        Measurement<UnitAngle>(
                            value: sectorAngleRange.upperBound,
                            unit: .degrees
                        ),
                        format: directionFormat
                    )
                }
                .listRowSeparator(.hidden, edges: .top)
                
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
                )
                .listRowSeparator(.hidden, edges: [.top])
                
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
                )
                .listRowSeparator(.hidden, edges: [.top])
            }
        }
    }
}

#Preview {
    ShowGeodesicSectorAndEllipseView()
}
