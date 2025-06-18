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
    
    @State var semiAxis1Length: Double = 10
    @State var semiAxis2Length: Double = 10
    @State var axisDirection: Double = 10
    @State var maxSegmentLength: Double = 10
    @State var sectorAngle: Double = 10
    @State var startDirection: Double = 10
    @State var maxPointCount: Double = 10
    @State var isPresented: Bool = false
    @State var geometryTypes: [String] = ["Polygon", "Polyline", "Point"]
    @State private var selectedGeometryType: GeometryType = .polygon
    
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
                        Button("Angle") {
                            isPresented.toggle()
                        }.popover(isPresented: $isPresented) {
                            Form {
                                Section(
                                    header: Text("Axis Direction")
                                ) {
                                    Slider(value: $startDirection, in: 0...10) {
                                        Text("Slider")
                                    } minimumValueLabel: {
                                        Text("0").font(.title2).fontWeight(.thin)
                                    } maximumValueLabel: {
                                        Text("10").font(.title2).fontWeight(.thin)
                                    }
                                }
                                Section(
                                    header: Text("Max Point Count")
                                ) {
                                    Stepper(
                                        "Point Count:\(maxPointCount)",
                                        value: $maxPointCount,
                                        in: 0...10
                                    )
                                }
                                Section(
                                    header: Text("Max Segment Length")
                                ) {
                                    Slider(value: $maxSegmentLength, in: 0...10) {
                                        Text("Slider")
                                    } minimumValueLabel: {
                                        Text("0").font(.title2).fontWeight(.thin)
                                    } maximumValueLabel: {
                                        Text("10").font(.title2).fontWeight(.thin)
                                    }
                                }
                                Section {
                                    Picker("Geometry Type", selection: $selectedGeometryType) {
                                        ForEach(GeometryType.allCases, id: \.self) { mode in
                                            Text(mode.label)
                                        }
                                    }
                                }
                                Section(
                                    header: Text("Sector Angle")
                                ) {
                                    Slider(value: $startDirection, in: 0...10) {
                                        Text("Slider")
                                    } minimumValueLabel: {
                                        Text("0").font(.title2).fontWeight(.thin)
                                    } maximumValueLabel: {
                                        Text("10").font(.title2).fontWeight(.thin)
                                    }
                                }
                                Section(
                                    header: Text("Semi Axis 1 Length")
                                ) {
                                    Slider(value: $startDirection, in: 0...10) {
                                        Text("Slider")
                                    } minimumValueLabel: {
                                        Text("0").font(.title2).fontWeight(.thin)
                                    } maximumValueLabel: {
                                        Text("10").font(.title2).fontWeight(.thin)
                                    }
                                }
                                
                                Section(
                                    header: Text("Semi Axis 2 Length")
                                ) {
                                    Slider(value: $startDirection, in: 0...10) {
                                        Text("Slider")
                                    } minimumValueLabel: {
                                        Text("0").font(.title2).fontWeight(.thin)
                                    } maximumValueLabel: {
                                        Text("10").font(.title2).fontWeight(.thin)
                                    }
                                }
                                Section(
                                    header: Text("Semi Axis 2 Length")
                                ) {
                                    Slider(value: $startDirection, in: 0...10) {
                                        Text("Slider")
                                    } minimumValueLabel: {
                                        Text("0").font(.title2).fontWeight(.thin)
                                    } maximumValueLabel: {
                                        Text("10").font(.title2).fontWeight(.thin)
                                    }
                                }
                            }.presentationDetents([.medium])
                        }
                        Spacer()
                        Button("Axis") { }
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
            
            var ellipseLineSymbol = SimpleLineSymbol(style: .dash, color: .red, width: 2)
            let ellipseGeometry = GeometryEngine.geodesicEllipse(parameters: parameters)
            ellipseGraphic = Graphic(geometry: ellipseGeometry)
            graphicOverlay = GraphicsOverlay(graphics: [Graphic(geometry: ellipseGeometry)])
            graphicOverlay.renderer = SimpleRenderer(symbol: ellipseLineSymbol)
        }
        
        func updateSector(tapPoint: Point) {
            var sectorParams = GeodesicSectorParameters<ArcGIS.Polygon>()
            sectorParams.center = tapPoint
            sectorParams.axisDirection = 45
            sectorParams.maxPointCount = 100
            sectorParams.maxSegmentLength = 20
            sectorParams.sectorAngle = 90
            sectorParams.semiAxis1Length = 200
            sectorParams.semiAxis2Length = 400
            sectorParams.startDirection = 0
            
            var sectorGeometry = GeometryEngine.geodesicSector(parameters: sectorParams)
            
            sectorGraphic = Graphic(geometry: sectorGeometry, symbol: sectorLineSymbol)
            graphicOverlay.addGraphic(sectorGraphic)
        }
    }
    /// The types of the geometries supported by this sample.
}

#Preview {
    ShowGeodesicSectorAndEllipseView()
}
