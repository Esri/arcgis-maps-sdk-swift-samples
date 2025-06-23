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
    /// The data model that helps determine the view. It is an objerved object.
    @StateObject private var model = Model()
    
    /// The map point selected by the user when tapping on the map.
    @State private var tapPoint: Point?
    
    /// Manages the presentation state of the menu.
    @State private var isPresented: Bool = false
    
    var body: some View {
        MapViewReader { proxy in
            MapView(
                map: model.map,
                graphicsOverlays: [
                    model.ellipseGraphicOverlay,
                    model.sectorGraphicOverlay
                ]
            )
            .onSingleTapGesture { _, tapPoint in
                self.tapPoint = tapPoint
            }
            .task(id: tapPoint) {
                if let tapPoint {
                    await proxy.setViewpoint(
                        Viewpoint(
                            center: tapPoint, scale: 1e7
                        )
                    )
                    model.updateSector(tapPoint: tapPoint)
                }
            }
            .toolbar {
                // The menu which holds the options that change the ellipse and sector.
                ToolbarItemGroup(placement: .bottomBar) {
                    Button("Geodesic Sector & Ellipse Settings") {
                        isPresented.toggle()
                    }
                    .popover(isPresented: $isPresented) {
                        Form {
                            Section {
                                ParameterSlider(
                                    label: "Axis Direction:",
                                    value: $model.axisDirection,
                                    range: 0...360,
                                    tapPoint: tapPoint
                                ) {
                                    model.updateSector(tapPoint: tapPoint)
                                }
                                Stepper(value: $model.maxPointCount, in: 0...1000, step: 1) {
                                    Text("Max Point Count:  \(String(format: "%d", model.maxPointCount))")
                                }
                                .font(.caption)
                                .onChange(of: model.maxPointCount) {
                                    model.updateSector(tapPoint: tapPoint)
                                }
                                ParameterSlider(
                                    label: "Max Segment Length:",
                                    value: $model.maxSegmentLength,
                                    range: 1...1000, tapPoint:
                                        tapPoint
                                ) {
                                    model.updateSector(tapPoint: tapPoint)
                                }
                                GeometryTypeMenu(
                                    selected: $model.selectedGeometryType
                                )
                                .onChange(of: model.selectedGeometryType) {
                                    model.updateSector(tapPoint: tapPoint)
                                }
                                ParameterSlider(
                                    label: "Sector Angle:",
                                    value: $model.sectorAngle,
                                    range: 0...360,
                                    tapPoint: tapPoint
                                ) {
                                    model.updateSector(tapPoint: tapPoint)
                                }
                                ParameterSlider(
                                    label: "Semi Axis 1 Length:",
                                    value: $model.semiAxis1Length,
                                    range: 0...1000,
                                    tapPoint: tapPoint
                                ) {
                                    model.updateSector(tapPoint: tapPoint)
                                }
                                ParameterSlider(
                                    label: "Semi Axis 2 Length:",
                                    value: $model.semiAxis2Length,
                                    range: 0...1000,
                                    tapPoint: tapPoint
                                ) {
                                    model.updateSector(tapPoint: tapPoint)
                                }
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
        var map = Map(basemapStyle: .arcGISTopographic)
        
        /// The graphics overlay that will be displayed on the map view.
        /// This will hold the graphics that show the ellipse path.
        var ellipseGraphicOverlay = GraphicsOverlay()
        
        /// The graphics overlay that will be displayed on the map view.
        /// This will display a highlighted section of the ellipse path.
        var sectorGraphicOverlay = GraphicsOverlay()
        
        private let sectorLineSymbol = SimpleLineSymbol(style: .solid, color: .green, width: 2)
        private let sectorMarkerSymbol = SimpleMarkerSymbol(style: .circle, color: .green, size: 2)
        private let ellipseLineSymbol = SimpleLineSymbol(style: .dash, color: .red, width: 2)
        private let sectorFillSymbol = SimpleFillSymbol(style: .solid, color: .green)
        
        private var ellipseGraphic: Graphic!
        private var sectorGraphic: Graphic!
        
        /// The direction (in degrees) of the ellipse's major axis.
        @Published var axisDirection: Double = 45
        @Published var maxSegmentLength: Double = 1
        @Published var sectorAngle: Double = 90
        @Published var maxPointCount: Int = 2000
        @Published var semiAxis1Length: Double = 200
        @Published var semiAxis2Length: Double = 100
        @Published var selectedGeometryType: GeometryType = .polygon
        @Published var startDirection: Double = 45
        
        func updateSector(tapPoint: Point?) {
            guard let tapPoint = tapPoint else { return }
            ellipseGraphicOverlay.removeAllGraphics()
            sectorGraphicOverlay.removeAllGraphics()
            setupSector(tapPoint: tapPoint, geometryType: selectedGeometryType)
            updateEllipse(tapPoint: tapPoint)
        }
        
        private func setupSector(tapPoint: Point, geometryType: GeometryType) {
            switch geometryType {
            case .point:
                // Generate sector as a multipoint (symbols)
                var params = GeodesicSectorParameters<Multipoint>()
                fillSectorParams(&params, center: tapPoint)
                let geometry = GeometryEngine.geodesicSector(parameters: params)
                addSectorGraphic(geometry: geometry, symbol: sectorMarkerSymbol)
            case .polyline:
                // Generate sector as a polyline (outlined arc)
                var params = GeodesicSectorParameters<Polyline>()
                fillSectorParams(&params, center: tapPoint)
                let geometry = GeometryEngine.geodesicSector(parameters: params)
                addSectorGraphic(geometry: geometry, symbol: sectorLineSymbol)
            case .polygon:
                // Generate sector as a filled polygon
                var params = GeodesicSectorParameters<Polygon>()
                fillSectorParams(&params, center: tapPoint)
                let geometry = GeometryEngine.geodesicSector(parameters: params)
                addSectorGraphic(geometry: geometry, symbol: sectorFillSymbol)
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
        private func addSectorGraphic(geometry: Geometry?, symbol: Symbol) {
            guard let geometry = geometry else { return }
            sectorGraphic = Graphic(geometry: geometry, symbol: symbol)
            sectorGraphicOverlay.renderer = SimpleRenderer(symbol: symbol)
            sectorGraphicOverlay.addGraphic(sectorGraphic)
        }
        
        /// Generates and adds a geodesic ellipse graphic based on the current settings and tap point.
        private func updateEllipse(tapPoint: Point?) {
            guard let tapPoint = tapPoint else {
                return
            }
            let parameters = GeodesicEllipseParameters<ArcGIS.Polygon>(
                axisDirection: axisDirection,
                center: tapPoint,
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
        var tapPoint: Point?
        let onUpdate: () -> Void
        
        var body: some View {
            Slider(value: $value, in: range) {
            } minimumValueLabel: {
                Text(label)
                    .font(.caption)
            } maximumValueLabel: {
                Text("\(String(format: "%.0f", value))")
                    .font(.caption)
            }
            .onChange(of: value) {
                onUpdate()
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
