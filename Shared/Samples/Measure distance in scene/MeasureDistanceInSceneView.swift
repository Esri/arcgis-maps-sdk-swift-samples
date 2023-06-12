// Copyright 2023 Esri
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

import SwiftUI
import ArcGIS

struct MeasureDistanceInSceneView: View {
    /// A scene with an imagery basemap.
    @State private var scene = ArcGIS.Scene(basemapStyle: .arcGISTopographic)
    
    /// An analysis overlay for location distance measurement.
    @State private var analysisOverlay = AnalysisOverlay()
    
    /// A string for the direct distance measurement of the location distance measurement.
    @State private var directDistanceText = "--"
    
    /// A string for the horizontal distance measurement of the location distance measurement.
    @State private var horizontalDistanceText = "--"
    
    /// A string for the vertical distance measurement of the location distance measurement.
    @State private var verticalDistanceText = "--"
    
    /// The unit system for the location distance measurement, selected by the picker.
    @State private var unitSystemSelection: UnitSystem = .metric
    
    /// The location distance measurement.
    private let locationDistanceMeasurement = LocationDistanceMeasurement(
        startLocation: Point(x: -4.494677, y: 48.384472, z: 24.772694, spatialReference: .wgs84),
        endLocation: Point(x: -4.495646, y: 48.384377, z: 58.501115, spatialReference: .wgs84)
    )
    
    /// A measurement formatter for converting the distances to strings.
    private let measurementFormatter: MeasurementFormatter = {
        let measurementFormatter = MeasurementFormatter()
        measurementFormatter.unitOptions = .providedUnit
        measurementFormatter.numberFormatter.minimumFractionDigits = 2
        measurementFormatter.numberFormatter.maximumFractionDigits = 2
        return measurementFormatter
    }()
    
    init() {
        // Add elevation source to the base surface of the scene with the service URL.
        let elevationSource = ArcGISTiledElevationSource(url: .elevationService)
        scene.baseSurface.addElevationSource(elevationSource)
        
        // Create the building layer and add it to the scene.
        let buildingsLayer = ArcGISSceneLayer(url: .brestBuildingsService)
        scene.addOperationalLayer(buildingsLayer)
        
        // Set scene the viewpoint specified by the camera position.
        let lookAtPoint = Envelope(
            min: locationDistanceMeasurement.startLocation,
            max: locationDistanceMeasurement.endLocation
        ).center
        let camera = Camera(lookingAt: lookAtPoint, distance: 200, heading: 0, pitch: 45, roll: 0)
        scene.initialViewpoint = Viewpoint(boundingGeometry: lookAtPoint, camera: camera)
        
        // Create analysis overlay.
        analysisOverlay.addAnalysis(locationDistanceMeasurement)
    }
    
    var body: some View {
        VStack {
            SceneView(scene: scene, analysisOverlays: [analysisOverlay])
                .onSingleTapGesture { _, scenePoint in
                    if locationDistanceMeasurement.startLocation != locationDistanceMeasurement.endLocation {
                        locationDistanceMeasurement.startLocation = scenePoint!
                    }
                    locationDistanceMeasurement.endLocation = scenePoint!
                }
                .task {
                    // Set distance text when there are measurements updates.
                    for await measurements in locationDistanceMeasurement.measurements {
                        directDistanceText = measurementFormatter.string(from: measurements.directDistance)
                        horizontalDistanceText = measurementFormatter.string(from: measurements.horizontalDistance)
                        verticalDistanceText = measurementFormatter.string(from: measurements.verticalDistance)
                    }
                }
            
            // Distance texts.
            Text("Direct: \(directDistanceText)")
            Text("Horizontal: \(horizontalDistanceText)")
            Text("Vertical: \(verticalDistanceText)")
            
            // Unit system picker.
            Picker("", selection: $unitSystemSelection) {
                Text("Imperial").tag(UnitSystem.imperial)
                Text("Metric").tag(UnitSystem.metric)
            }
            .pickerStyle(.segmented)
            .padding()
            .onChange(of: unitSystemSelection) { _ in
                locationDistanceMeasurement.unitSystem = unitSystemSelection
            }
        }
    }
}

private extension URL {
    /// A elevation image service URL.
    static var elevationService: URL {
        URL(string: "https://scene.arcgis.com/arcgis/rest/services/BREST_DTM_1M/ImageServer")!
    }
    
    /// A scene service URL for buildings in Brest, France.
    static var brestBuildingsService: URL {
        URL(string: "https://tiles.arcgis.com/tiles/P3ePLMYs2RVChkJx/arcgis/rest/services/Buildings_Brest/SceneServer/layers/0")!
    }
}
