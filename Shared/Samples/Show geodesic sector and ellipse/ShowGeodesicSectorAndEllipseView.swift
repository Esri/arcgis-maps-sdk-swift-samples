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
    @State var isPresented: Bool = false
    
    var body: some View {
        MapViewReader { proxy in
            MapView(map: model.map, graphicsOverlays: [model.graphicOverlay])
                .onSingleTapGesture { _, tapPoint in
                    self.tapPoint = tapPoint
                }
                .task(id: tapPoint) {
                    if let tapPoint {
                        await proxy.setViewpoint(Viewpoint(center: tapPoint, scale: 1e8))
                        model.set(tapPoint: tapPoint)
                        model.updateSector(tapPoint: tapPoint)
                    }
                }
                .toolbar {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button("Geodesic Sector & Ellipse") {
                            isPresented.toggle()
                        }.popover(isPresented: $isPresented) {
                            Form {
                                Section {
                                    ParameterSlider(label: "Axis Direction:", value: $model.axisDirection, range: 0...10, tapPoint: tapPoint) {
                                        model.updateSector(tapPoint: tapPoint)
                                    }
                                    
                                    Stepper(
                                        "Max Point Count: \(String(format: "%.2f", model.maxPointCount))",
                                        value: $model.maxPointCount,
                                        in: 0...10
                                    ).font(.caption).onChange(of: model.maxPointCount) {
                                        model.updateSector(tapPoint: tapPoint)
                                    }
                                    
                                    ParameterSlider(label: "Max Segment Length:", value: $model.maxSegmentLength, range: 0...10, tapPoint: tapPoint) {
                                        model.updateSector(tapPoint: tapPoint)
                                    }
                                    
                                    Menu {
                                        ForEach(GeometryType.allCases, id: \.self) { mode in
                                            Button {
                                                model.selectedGeometryType = mode
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
                                            Text(model.selectedGeometryType.label)
                                                .fontWeight(.bold)
                                                .foregroundColor(.gray)
                                            VStack {
                                                Image(systemName: "chevron.up")
                                                    .font(.caption2).fontWeight(.medium)
                                                Image(systemName: "chevron.down")
                                                    .font(.caption2).fontWeight(.medium)
                                            }
                                            .foregroundColor(.gray)
                                        }
                                        .font(.caption)
                                    }
                                    
                                    ParameterSlider(label: "Sector Angle:", value: $model.sectorAngle, range: 0...10, tapPoint: tapPoint) {
                                        model.updateSector(tapPoint: tapPoint)
                                    }
                                    
                                    ParameterSlider(label: "Semi Axis 1 Length:", value: $model.semiAxis1Length, range: 0...10, tapPoint: tapPoint) {
                                        model.updateSector(tapPoint: tapPoint)
                                    }
                                    
                                    ParameterSlider(label: "Semi Axis 2 Length:", value: $model.semiAxis2Length, range: 0...10, tapPoint: tapPoint) {
                                        model.updateSector(tapPoint: tapPoint)
                                    }
                                }
                            }.presentationDetents([.medium])
                        }
                    }
                }
        }
    }
}

private extension ShowGeodesicSectorAndEllipseView {
    enum GeometryType: CaseIterable {
        case point, polyline, polygon
        
        /// A human-readable label for the geometry type.
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
        var graphicOverlay = GraphicsOverlay()
        
        var sectorFillSymbol = SimpleFillSymbol(style: .solid, color: .green)
        var sectorLineSymbol = SimpleLineSymbol(style: .solid, color: .green, width: 3)
        var sectorMarkerSymbol = SimpleMarkerSymbol(style: .circle, color: .green, size: 3)
        
        var ellipseGraphic: Graphic!
        var sectorGraphic: Graphic!
        
        @Published var axisDirection: Double = 0
        @Published var maxSegmentLength: Double = 10
        @Published var sectorAngle: Double = 10
        @Published var maxPointCount: Int = 10
        @Published var semiAxis1Length: Double = 10
        @Published var semiAxis2Length: Double = 10
        @Published var selectedGeometryType: GeometryType = .polygon
        @Published var startDirection: Double = 10
        
        func set(tapPoint: Point) {
            let parameters = GeodesicEllipseParameters<ArcGIS.Polygon>(
                axisDirection: -45,
                center: tapPoint,
                linearUnit: .kilometers,
                maxPointCount: 100,
                maxSegmentLength: 20,
                semiAxis1Length: 200,
                semiAxis2Length: 400
            )
            
            let ellipseLineSymbol = SimpleLineSymbol(style: .dash, color: .red, width: 2)
            let ellipseGeometry = GeometryEngine.geodesicEllipse(parameters: parameters)
            ellipseGraphic = Graphic(geometry: ellipseGeometry)
            graphicOverlay = GraphicsOverlay(graphics: [Graphic(geometry: ellipseGeometry)])
            graphicOverlay.renderer = SimpleRenderer(symbol: ellipseLineSymbol)
        }
        
        func updateSector(tapPoint: Point?) {
            guard let tapPoint = tapPoint else { return }
            var sectorParams = GeodesicSectorParameters<ArcGIS.Polygon>()
            sectorParams.center = tapPoint
            sectorParams.axisDirection = axisDirection
            sectorParams.maxPointCount = maxPointCount
            sectorParams.maxSegmentLength = maxSegmentLength
            sectorParams.sectorAngle = sectorAngle
            sectorParams.semiAxis1Length = semiAxis1Length
            sectorParams.semiAxis2Length = semiAxis2Length
            sectorParams.startDirection = startDirection
            let sectorGeometry = GeometryEngine.geodesicSector(parameters: sectorParams)
            sectorGraphic = Graphic(geometry: sectorGeometry, symbol: sectorLineSymbol)
            graphicOverlay.addGraphic(sectorGraphic)
        }
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
            Text(label).font(.caption)
        } maximumValueLabel: {
            Text("\(String(format: "%.2f", value))").font(.caption)
        }
        .onChange(of: value) {
            onUpdate()
        }
    }
}

#Preview {
    ShowGeodesicSectorAndEllipseView()
}
