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
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// A string for the direct distance of the location distance measurement.
    @State private var directDistanceText = "--"
    
    /// A string for the horizontal distance of the location distance measurement.
    @State private var horizontalDistanceText = "--"
    
    /// A string for the vertical distance of the location distance measurement.
    @State private var verticalDistanceText = "--"
    
    /// The unit system for the location distance measurement, selected by the picker.
    @State private var unitSystemSelection: UnitSystem = .metric
    
    /// The overlay instruction message text.
    @State private var instructionText: String = .startMessage
    
    var body: some View {
        VStack {
            SceneViewReader { sceneViewProxy in
                SceneView(scene: model.scene, analysisOverlays: [model.analysisOverlay])
                    .onSingleTapGesture { screenPoint, _ in
                        // Set the start and end locations when the screen is tapped.
                        Task {
                            guard let location = try? await sceneViewProxy.location(
                                fromScreenPoint: screenPoint
                            ) else { return }
                            
                            if model.locationDistanceMeasurement.startLocation != model.locationDistanceMeasurement.endLocation {
                                model.locationDistanceMeasurement.startLocation = location
                                instructionText = .endMessage
                            } else {
                                instructionText = .startMessage
                            }
                            model.locationDistanceMeasurement.endLocation = location
                        }
                    }
                    .onDragGesture { _, _ in
                        // Drag gesture is active when user has first set the start location.
                        return model.locationDistanceMeasurement.startLocation == model.locationDistanceMeasurement.endLocation
                    } onChanged: { screenPoint, _ in
                        // Move the end location on drag gesture.
                        Task {
                            guard let location = try? await sceneViewProxy.location(
                                fromScreenPoint: screenPoint
                            ) else { return }
                            model.locationDistanceMeasurement.endLocation = location
                        }
                    } onEnded: { _, _ in
                        instructionText = .startMessage
                    }
                    .task {
                        // Set distance text when there is a measurements update.
                        for await measurements in model.locationDistanceMeasurement.measurements {
                            directDistanceText = measurements.directDistance.formatted(.distance)
                            horizontalDistanceText = measurements.horizontalDistance.formatted(.distance)
                            verticalDistanceText = measurements.verticalDistance.formatted(.distance)
                        }
                    }
                    .overlay(alignment: .top) {
                        // Instruction text.
                        Text(instructionText)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(8)
                            .background(.thinMaterial, ignoresSafeAreaEdges: .horizontal)
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
                model.locationDistanceMeasurement.unitSystem = unitSystemSelection
            }
        }
    }
}

private extension MeasureDistanceInSceneView {
    /// The view model for the sample.
    class Model: ObservableObject {
        /// A scene with an imagery basemap.
        let scene = {
            let scene = ArcGIS.Scene(basemapStyle: .arcGISTopographic)
            
            // Add elevation source to the base surface of the scene with the service URL.
            let elevationSource = ArcGISTiledElevationSource(url: .worldElevationService)
            scene.baseSurface.addElevationSource(elevationSource)
            
            // Create the building layer and add it to the scene.
            let buildingsLayer = ArcGISSceneLayer(url: .brestBuildingsService)
            scene.addOperationalLayer(buildingsLayer)
            
            return scene
        }()
        
        /// An analysis overlay for location distance measurement.
        let analysisOverlay = AnalysisOverlay()
        
        /// The location distance measurement.
        let locationDistanceMeasurement = LocationDistanceMeasurement(
            startLocation: Point(x: -4.494677, y: 48.384472, z: 24.772694, spatialReference: .wgs84),
            endLocation: Point(x: -4.495646, y: 48.384377, z: 58.501115, spatialReference: .wgs84)
        )
        
        init() {
            // Set scene to the viewpoint specified by the location distance measurement.
            let lookAtPoint = Envelope(
                min: locationDistanceMeasurement.startLocation,
                max: locationDistanceMeasurement.endLocation
            ).center
            let camera = Camera(lookingAt: lookAtPoint, distance: 200, heading: 0, pitch: 45, roll: 0)
            scene.initialViewpoint = Viewpoint(latitude: .nan, longitude: .nan, scale: .nan, camera: camera)
            
            // Add location distance measurement to the analysis overlay to display it.
            analysisOverlay.addAnalysis(locationDistanceMeasurement)
        }
    }
}

private extension FormatStyle where Self == Measurement<UnitLength>.FormatStyle {
    /// The format style for the distances.
    static var distance: Self {
        .measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(2)))
    }
}

private extension String {
    /// The user instruction message for setting the start location.
    static let startMessage = "Tap on the map to set the start location."
    
    /// The user instruction message for setting the end location.
    static let endMessage = "Tap and drag on the map to set the end location."
}

private extension URL {
    /// A world elevation service from Terrain3D ArcGIS REST service.
    static var worldElevationService: URL {
        URL(string: "https://elevation3d.arcgis.com/arcgis/rest/services/WorldElevation3D/Terrain3D/ImageServer")!
    }
    
    /// A scene service URL for the buildings in Brest, France.
    static var brestBuildingsService: URL {
        URL(string: "https://tiles.arcgis.com/tiles/P3ePLMYs2RVChkJx/arcgis/rest/services/Buildings_Brest/SceneServer/layers/0")!
    }
}

#Preview {
    MeasureDistanceInSceneView()
}
