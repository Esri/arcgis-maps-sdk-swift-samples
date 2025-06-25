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
        MapViewReader { proxy in
            MapView(
                map: model.map,
                graphicsOverlays: model.graphicOverlays
            )
            .onSingleTapGesture { _, tapPoint in
                model.centerPoint = tapPoint
            }
            .task(id: model.centerPoint) {
                guard let centerPoint = model.centerPoint else { return }
                await proxy.setViewpoint(
                    Viewpoint(center: centerPoint, scale: 1e7)
                )
            }
            .toolbar {
                // The menu which holds the options that change the ellipse and sector.
                ToolbarItemGroup(placement: .bottomBar) {
                    Button("Settings") {
                        isPresented = true
                    }
                    .disabled(model.centerPoint == nil)
                    .popover(isPresented: $isPresented) {
                        Form {
                            ParameterSlider(
                                label: "Axis Direction:",
                                value: $model.axisDirection,
                                range: 0...360
                            )
                            .onChange(of: model.axisDirection) {
                                model.refreshSector()
                            }
                            
                            Stepper(
                                value: $model.maxPointCount,
                                in: 0...1000,
                                step: 1
                            ) {
                                Text("Max Point Count:  \(String(format: "%d", model.maxPointCount))")
                            }
                            .font(.caption)
                            .onChange(of: model.maxPointCount) {
                                model.refreshSector()
                            }
                            
                            ParameterSlider(
                                label: "Max Segment Length:",
                                value: $model.maxSegmentLength,
                                range: 1...1000
                            )
                            .onChange(of: model.maxSegmentLength) {
                                model.refreshSector()
                            }
                            
                            GeometryTypeMenu(
                                selected: $model.selectedGeometryType
                            )
                            .onChange(of: model.selectedGeometryType) {
                                model.refreshSector()
                            }
                            
                            ParameterSlider(
                                label: "Sector Angle:",
                                value: $model.sectorAngle,
                                range: 0...360
                            )
                            .onChange(of: model.sectorAngle) {
                                model.refreshSector()
                            }
                            
                            ParameterSlider(
                                label: "Semi Axis 1 Length:",
                                value: $model.semiAxis1Length,
                                range: 0...1000
                            )
                            .onChange(of: model.semiAxis1Length) {
                                model.refreshSector()
                            }
                            
                            ParameterSlider(
                                label: "Semi Axis 2 Length:",
                                value: $model.semiAxis2Length,
                                range: 0...1000
                            )
                            .onChange(of: model.semiAxis2Length) {
                                model.refreshSector()
                            }
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
        @Published var centerPoint: Point? {
            didSet {
                guard let center = centerPoint else { return }
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
        
        private let sectorLineSymbol = SimpleLineSymbol(style: .solid, color: .green, width: 2)
        private let sectorMarkerSymbol = SimpleMarkerSymbol(style: .circle, color: .green, size: 2)
        private let ellipseLineSymbol = SimpleLineSymbol(style: .dash, color: .red, width: 2)
        private let sectorFillSymbol = SimpleFillSymbol(style: .solid, color: .green)
        
        private var ellipseGraphic: Graphic!
        private var sectorGraphic: Graphic!
        
        /// The direction (in degrees) of the ellipse's major axis.
        @Published var axisDirection: Double = 45
        /// Controls the complexity of the geometries and the approximation of the ellipse curve.
        @Published var maxSegmentLength: Double = 1
        /// Changes the sectors shape.
        @Published var sectorAngle: Double = 90
        /// Controls the complexity of the geometries and the approximation of the ellipse curve.
        @Published var maxPointCount: Int = 1000
        /// Changes the length of ellipse shape on one axis.
        @Published var semiAxis1Length: Double = 200
        /// Changes the length of ellipse shape on one axis.
        @Published var semiAxis2Length: Double = 100
        /// Changes the geometry type which the sector is rendered.
        @Published var selectedGeometryType: GeometryType = .polygon
        /// Changes the direction of the sector.
        @Published var startDirection: Double = 45
        
        func refreshSector() {
            guard let center = centerPoint else { return }
            updateSector(center: center)
        }
        
        private func updateSector(center: Point) {
            ellipseGraphicOverlay.removeAllGraphics()
            sectorGraphicOverlay.removeAllGraphics()
            updateEllipse(center: center)
            setupSector(center: center, geometryType: selectedGeometryType)
        }
        
        private func setupSector(center: Point, geometryType: GeometryType) {
            switch geometryType {
            case .point:
                // Generate sector as a multipoint (symbols).
                var params = GeodesicSectorParameters<Multipoint>()
                fillSectorParams(&params, center: center)
                if let geometry = GeometryEngine.geodesicSector(parameters: params) {
                    addSectorGraphic(geometry: geometry, symbol: sectorMarkerSymbol)
                }
            case .polyline:
                // Generate sector as a polyline (outlined arc).
                var params = GeodesicSectorParameters<Polyline>()
                fillSectorParams(&params, center: center)
                if let geometry = GeometryEngine.geodesicSector(parameters: params) {
                    addSectorGraphic(geometry: geometry, symbol: sectorLineSymbol)
                }
            case .polygon:
                // Generate sector as a filled polygon.
                var params = GeodesicSectorParameters<Polygon>()
                fillSectorParams(&params, center: center)
                if let geometry = GeometryEngine.geodesicSector(parameters: params) {
                    addSectorGraphic(geometry: geometry, symbol: sectorFillSymbol)
                }
            }
        }
        
        /// Populates a `GeodesicSectorParameters<T>` instance with current user-defined values.
        /// - Parameter params: A reference to the parameter struct that will be filled.
        /// - Parameter center: The center point for the sector/ellipse.
        private func fillSectorParams<T>(_ params: inout GeodesicSectorParameters<T>, center: Point) {
            params.center = center
            params.axisDirection = axisDirection
            params.maxPointCount = maxPointCount
            params.maxSegmentLength = maxSegmentLength
            params.sectorAngle = sectorAngle
            params.semiAxis1Length = semiAxis1Length
            params.semiAxis2Length = semiAxis2Length
            params.startDirection = startDirection
            params.linearUnit = .miles
        }
        
        /// Adds a sector graphic to the overlay and applies the appropriate renderer.
        private func addSectorGraphic(geometry: Geometry, symbol: Symbol) {
            sectorGraphic = Graphic(geometry: geometry, symbol: symbol)
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
            ellipseGraphic = Graphic(geometry: ellipseGeometry, symbol: ellipseLineSymbol)
            ellipseGraphicOverlay.addGraphic(ellipseGraphic)
        }
    }
    
    /// A reusable UI component for adjusting a numeric parameter using a slider.
    /// Updates the sector/ellipse dynamically when changed.
    struct ParameterSlider: View {
        let label: String
        @Binding var value: Double
        let range: ClosedRange<Double>
        
        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                let format = FloatingPointFormatStyle<Double>()
                    .precision(.fractionLength(0))
                    .grouping(.never)
                LabeledContent(
                    label,
                    value: value,
                    format: format
                )
                .font(.caption)
                Slider(value: $value, in: range) {
                    Text(label)
                        .font(.caption)
                } minimumValueLabel: {
                    Text(range.lowerBound, format: format)
                        .font(.caption)
                } maximumValueLabel: {
                    Text(range.upperBound, format: format)
                        .font(.caption)
                }
                .listRowSeparator(.hidden, edges: [.top])
            }
        }
    }
    
    /// A menu component that allows the user to choose between point, polyline, or polygon geometry types for the sector.
    struct GeometryTypeMenu: View {
        @Binding var selected: GeometryType
        
        var body: some View {
            Menu {
                ForEach(GeometryType.allCases, id: \.self) { mode in
                    Button {
                        selected = mode
                    } label: {
                        Text(mode.label)
                            .font(.caption)
                            .foregroundColor(.black)
                    }
                }
            } label: {
                HStack {
                    Text("Geometry Type: ")
                        .foregroundColor(.black)
                    Spacer()
                    Text(selected.label)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                    VStack {
                        Image(systemName: "chevron.up")
                            .font(.caption2)
                            .fontWeight(.medium)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.gray)
                }
                .font(.caption)
            }
        }
    }
}

#Preview {
    ShowGeodesicSectorAndEllipseView()
}
