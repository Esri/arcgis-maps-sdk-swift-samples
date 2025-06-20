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
    @StateObject private var model = Model()
    
    @State private var tapPoint: Point?
    @State private var isPresented: Bool = false
    
    var body: some View {
        MapViewReader { proxy in
            MapView(
                map: model.map,
                graphicsOverlays: [model.ellipseGraphicOverlay, model.sectorGraphicOverlay]
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
                    
                    model.set(tapPoint: tapPoint)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button("Geodesic Sector & Ellipse") {
                        isPresented.toggle()
                    }
                    .popover(isPresented: $isPresented) {
                        Form {
                            Section {
                                ParameterSlider(
                                    label: "Axis Direction:", value: $model.axisDirection, range: 0...360, tapPoint: tapPoint
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
                                    label: "Max Segment Length:", value: $model.maxSegmentLength, range: 1...1000, tapPoint: tapPoint
                                ) {
                                    model.updateSector(tapPoint: tapPoint)
                                }
                                
                                GeometryTypeMenu(
                                    selected: $model.selectedGeometryType
                                )
                                .onChange(of: model.selectedGeometryType
                                ) {
                                    model.updateSector(tapPoint: tapPoint)
                                }
                                
                                ParameterSlider(
                                    label: "Sector Angle:", value: $model.sectorAngle, range: 0...360, tapPoint: tapPoint
                                ) {
                                    model.updateSector(tapPoint: tapPoint)
                                }
                                
                                ParameterSlider(
                                    label: "Semi Axis 1 Length:", value: $model.semiAxis1Length, range: 0...1000, tapPoint: tapPoint
                                ) {
                                    model.updateSector(tapPoint: tapPoint)
                                }
                                
                                ParameterSlider(
                                    label: "Semi Axis 2 Length:", value: $model.semiAxis2Length, range: 0...1000, tapPoint: tapPoint
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
    
    @MainActor
    class Model: ObservableObject {
        var map = Map(basemapStyle: .arcGISTopographic)
        var ellipseGraphicOverlay = GraphicsOverlay()
        var sectorGraphicOverlay = GraphicsOverlay()
        
        var sectorLineSymbol = SimpleLineSymbol(style: .solid, color: .blue, width: 2)
        var sectorMarkerSymbol = SimpleMarkerSymbol(style: .circle, color: .green, size: 2)
        let ellipseLineSymbol = SimpleLineSymbol(style: .dash, color: .red, width: 2)
        var sectorFillSymbol = SimpleFillSymbol(style: .solid, color: .green)
        
        var ellipseGraphic: Graphic!
        var sectorGraphic: Graphic!
        
        @Published var axisDirection: Double = 45
        @Published var maxSegmentLength: Double = 1
        @Published var sectorAngle: Double = 90
        @Published var maxPointCount: Int = 2000
        @Published var semiAxis1Length: Double = 200
        @Published var semiAxis2Length: Double = 100
        @Published var selectedGeometryType: GeometryType = .polygon
        @Published var startDirection: Double = 45
        
        func set(tapPoint: Point) {
            updateSector(tapPoint: tapPoint)
        }
        
        func updateSector(tapPoint: Point?) {
            guard let tapPoint = tapPoint else { return }
            ellipseGraphicOverlay.removeAllGraphics()
            sectorGraphicOverlay.removeAllGraphics()
            switch selectedGeometryType {
            case .point:
                setupPoint(tapPoint: tapPoint)
            case .polyline:
                setupPolyline(tapPoint: tapPoint)
            case .polygon:
                setupPolygon(tapPoint: tapPoint)
            }
            updateEllipse(tapPoint: tapPoint)
        }
        
        func setupPolygon(tapPoint: Point) {
            var sectorParams = GeodesicSectorParameters<ArcGIS.Polygon>()
            sectorParams.center = tapPoint
            sectorParams.axisDirection = axisDirection
            sectorParams.maxPointCount = maxPointCount
            sectorParams.maxSegmentLength = maxSegmentLength
            sectorParams.sectorAngle = sectorAngle
            sectorParams.semiAxis1Length = semiAxis1Length
            sectorParams.semiAxis2Length = semiAxis2Length
            sectorParams.startDirection = startDirection
            sectorParams.linearUnit = .miles
            let sectorGeometry = GeometryEngine.geodesicSector(parameters: sectorParams)
            sectorGraphic = Graphic(geometry: sectorGeometry, symbol: sectorFillSymbol)
            sectorGraphicOverlay.renderer = SimpleRenderer(symbol: sectorFillSymbol)
            sectorGraphicOverlay.addGraphic(sectorGraphic)
        }
        
        func setupPolyline(tapPoint: Point) {
            var sectorParams = GeodesicSectorParameters<ArcGIS.Polyline>()
            sectorParams.center = tapPoint
            sectorParams.axisDirection = axisDirection
            sectorParams.maxPointCount = maxPointCount
            sectorParams.maxSegmentLength = maxSegmentLength
            sectorParams.sectorAngle = sectorAngle
            sectorParams.semiAxis1Length = semiAxis1Length
            sectorParams.semiAxis2Length = semiAxis2Length
            sectorParams.startDirection = startDirection
            sectorParams.linearUnit = .miles
            let sectorGeometry = GeometryEngine.geodesicSector(parameters: sectorParams)
            sectorGraphic = Graphic(geometry: sectorGeometry, symbol: sectorLineSymbol)
            sectorGraphicOverlay.renderer = SimpleRenderer(symbol: sectorLineSymbol)
            sectorGraphicOverlay.addGraphic(sectorGraphic)
        }
        
        func setupPoint(tapPoint: Point) {
            var sectorParams = GeodesicSectorParameters<ArcGIS.Multipoint>()
            sectorParams.center = tapPoint
            sectorParams.axisDirection = axisDirection
            sectorParams.maxPointCount = maxPointCount
            sectorParams.maxSegmentLength = maxSegmentLength
            sectorParams.sectorAngle = sectorAngle
            sectorParams.semiAxis1Length = semiAxis1Length
            sectorParams.semiAxis2Length = semiAxis2Length
            sectorParams.startDirection = startDirection
            sectorParams.linearUnit = .miles
            let sectorGeometry = GeometryEngine.geodesicSector(parameters: sectorParams)
            sectorGraphic = Graphic(geometry: sectorGeometry, symbol: sectorMarkerSymbol)
            sectorGraphicOverlay.renderer = SimpleRenderer(symbol: sectorMarkerSymbol)
            sectorGraphicOverlay.addGraphic(sectorGraphic)
        }
        
        func updateEllipse(tapPoint: Point?) {
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
                Text("\(String(format: "%.2f", value))")
                    .font(.caption)
            }
            .onChange(of: value) {
                onUpdate()
            }
        }
    }
    
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
