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

struct ShowRealisticLightAndShadowsView: View {
    /// The view model for this sample.
    @StateObject private var model = Model()
    
    /// The date second value controlled by the slider.
    @State private var dateSecond: Float = Model.dateSecondsNoon
    
    /// The formatted text of the date controlled by the slider.
    @State private var dateTimeText: String = DateFormatter.localizedString(
        from: .startOfDay.advanced(by: TimeInterval(Model.dateSecondsNoon)),
        dateStyle: .medium,
        timeStyle: .short
    )
    
    /// The sun lighting mode of the scene view.
    @State private var lightingMode: SceneView.SunLighting = .lightAndShadows
    
    /// The sun date that gets passed into the scene view.
    @State private var sunDate = Date.startOfDay.advanced(by: TimeInterval(Model.dateSecondsNoon))
    
    var body: some View {
        VStack {
            SceneView(scene: model.scene)
                .atmosphereEffect(.realistic)
                .sunLighting(lightingMode)
                .sunDate(sunDate)
            
            Slider(value: $dateSecond, in: Model.dateSecondValueRange) {
                Text("Time of day")
            } minimumValueLabel: {
                Text("AM")
            } maximumValueLabel: {
                Text("PM")
            }
            .frame(maxWidth: 540)
            .onChange(of: dateSecond, perform: sliderValueChanged(toValue:))
            .padding(.horizontal)
        }
        .overlay(alignment: .top) {
            dateTimeOverlay
        }
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Picker("Lighting Mode", selection: $lightingMode) {
                    ForEach(SceneView.SunLighting.allCases, id: \.self) { mode in
                        Text(mode.label)
                    }
                }
            }
        }
    }
    
    /// An overlay showing the date time adjusted by the slider.
    var dateTimeOverlay: some View {
        Text(dateTimeText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(.thinMaterial, ignoresSafeAreaEdges: .horizontal)
    }
    
    /// Handles slider value changed event and set the scene view's sun date.
    /// - Parameter value: The slider's value.
    private func sliderValueChanged(toValue value: Float) {
        // A DateComponents struct to encapsulate the second value from the slider.
        let dateComponents = DateComponents(second: Int(value))
        sunDate = Calendar.current.date(byAdding: dateComponents, to: .startOfDay)!
        dateTimeText = DateFormatter.localizedString(from: sunDate, dateStyle: .medium, timeStyle: .short)
    }
}

extension ShowRealisticLightAndShadowsView {
    /// The model used to store the geo model and other expensive objects
    /// used in this view.
    class Model: ObservableObject {
        /// A scene with buildings.
        let scene: ArcGIS.Scene = {
            // Creates a scene layer from buildings REST service.
            let buildingsURL = URL(string: "https://tiles.arcgis.com/tiles/P3ePLMYs2RVChkJx/arcgis/rest/services/DevA_BuildingShells/SceneServer")!
            let buildingsLayer = ArcGISSceneLayer(url: buildingsURL)
            // Creates an elevation source from Terrain3D REST service.
            let elevationServiceURL = URL(string: "https://elevation3d.arcgis.com/arcgis/rest/services/WorldElevation3D/Terrain3D/ImageServer")!
            let elevationSource = ArcGISTiledElevationSource(url: elevationServiceURL)
            let surface = Surface()
            surface.addElevationSource(elevationSource)
            let scene = Scene(basemapStyle: .arcGISTopographic)
            scene.baseSurface = surface
            scene.addOperationalLayer(buildingsLayer)
            scene.initialViewpoint = Viewpoint(
                latitude: .zero,
                longitude: .zero,
                scale: .nan,
                camera: Camera(latitude: 45.54605, longitude: -122.69033, altitude: 500, heading: 162.58544, pitch: 72.0, roll: 0)
            )
            return scene
        }()
        
        /// The range of possible date second values.
        /// The range is 0 to 86,340 seconds ((60 seconds * 60 minutes * 24 hours)  - 60 seconds),
        /// which means 12 am to 11:59 pm.
        static var dateSecondValueRange: ClosedRange<Float> { 0...86340 }

        /// The number of seconds to represent 12 pm (60 seconds * 60 minutes * 12 hours).
        static let dateSecondsNoon: Float = 43200
    }
}

private extension SceneView.SunLighting {
    /// A human-readable label of the sun lighting mode.
    var label: String {
        switch self {
        case .lightAndShadows:
            return "Light and Shadows"
        case .light:
            return "Light Only"
        case .off:
            return "No Light"
        @unknown default:
            return "Unknown"
        }
    }
}

private extension Date {
    static let startOfDay = Calendar.current.startOfDay(for: .now)
}

#Preview {
    NavigationView {
        ShowRealisticLightAndShadowsView()
    }
}
