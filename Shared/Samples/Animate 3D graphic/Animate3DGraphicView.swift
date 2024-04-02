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

import ArcGIS
import SwiftUI

struct Animate3DGraphicView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// A Boolean value that indicates whether the full map view is showing.
    @State private var isShowingFullMap = false
    
    var body: some View {
        ZStack {
            /// The scene view with the plane model graphic.
            SceneView(
                scene: model.scene,
                cameraController: model.cameraController,
                graphicsOverlays: [model.sceneGraphicsOverlay]
            )
            
            /// The stats of the current position of the plane.
            VStack {
                HStack {
                    Spacer()
                    VStack {
                        StatRow("Altitude", value: model.animation.currentFrame.altitude.formatted(.length))
                        StatRow("Heading", value: model.animation.currentFrame.heading.formatted(.angle))
                        StatRow("Pitch", value: model.animation.currentFrame.pitch.formatted(.angle))
                        StatRow("Roll", value: model.animation.currentFrame.roll.formatted(.angle))
                    }
                    .frame(width: 170, height: 100)
                    .padding([.leading, .trailing])
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
                    .shadow(radius: 3)
                }
                .padding()
                Spacer()
            }
            
            /// The map view that tracks the plane on a 2D map.
            VStack {
                Spacer()
                HStack {
                    MapView(map: model.map, viewpoint: model.viewpoint, graphicsOverlays: [model.mapGraphicsOverlay])
                        .interactionModes([])
                        .attributionBarHidden(true)
                        .onSingleTapGesture { _, _ in
                            // Show/hide full map on tap.
                            withAnimation(.default.speed(2)) {
                                isShowingFullMap.toggle()
                            }
                        }
                        .frame(width: isShowingFullMap ? nil : 100, height: isShowingFullMap ? nil : 100)
                        .cornerRadius(10)
                        .shadow(radius: 3)
                    Spacer()
                }
                .padding()
                .padding(.bottom)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                SettingsView(label: "Mission") {
                    missionSettings
                }
                Spacer()
                
                /// The play/pause button for the animation.
                Button {
                    model.animation.isPlaying.toggle()
                } label: {
                    Image(systemName: model.animation.isPlaying ? "pause.fill" : "play.fill")
                }
                Spacer()
                
                SettingsView(label: "Camera") {
                    cameraSettings
                }
            }
        }
        .task {
            await model.monitorCameraController()
        }
    }
    
    /// The list containing the mission settings.
    private var missionSettings: some View {
        List {
            Section("Mission") {
                VStack {
                    StatRow("Progress", value: model.animation.progress.formatted(.rounded))
                    ProgressView(value: model.animation.progress)
                }
                .padding(.vertical)
                
                Picker("Mission Selection", selection: $model.currentMission) {
                    ForEach(Mission.allCases, id: \.self) { mission in
                        Text(mission.label)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            
            Section("Speed") {
                Picker("Animation Speed", selection: $model.animation.speed) {
                    ForEach(AnimationSpeed.allCases, id: \.self) { speed in
                        Text(String(describing: speed).capitalized)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
    }
    
    /// The list containing the camera controller settings.
    private var cameraSettings: some View {
        List {
            Section {
                ForEach(CameraProperty.allCases, id: \.self) { property in
                    VStack {
                        StatRow(property.label, value: model.cameraPropertyTexts[property] ?? "")
                        Slider(value: cameraPropertyBinding(for: property), in: property.range, step: 1)
                            .padding(.horizontal)
                    }
                }
            }
            
            Section {
                Toggle("Auto-Heading Enabled", isOn: $model.cameraController.autoHeadingIsEnabled)
                Toggle("Auto-Pitch Enabled", isOn: $model.cameraController.autoPitchIsEnabled)
                Toggle("Auto-Roll Enabled", isOn: $model.cameraController.autoRollIsEnabled)
            }
        }
    }
}

extension Animate3DGraphicView {
    /// Creates a binding to a camera controller property based on a given property.
    /// - Parameter property: The property associated with a corresponding camera controller property.
    /// - Returns: A binding to a camera controller property on the model.
    func cameraPropertyBinding(for property: CameraProperty) -> Binding<Double> {
        switch property {
        case .distance: return $model.cameraController.cameraDistance
        case .heading: return $model.cameraController.cameraHeadingOffset
        case .pitch: return $model.cameraController.cameraPitchOffset
        }
    }
    
    /// A view for displaying a statistic name and value in a row.
    struct StatRow: View {
        /// The name of the statistic.
        var label: String
        /// The formatted value of the statistic.
        var value: String
        
        init(_ label: String, value: String) {
            self.label = label
            self.value = value
        }
        
        var body: some View {
            HStack {
                Text(label)
                Spacer()
                Text(value)
            }
        }
    }
}

private extension FormatStyle where Self == Measurement<UnitLength>.FormatStyle {
    /// The format style for length measurements.
    static var length: Self {
        .measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0)))
    }
}

private extension FormatStyle where Self == Measurement<UnitAngle>.FormatStyle {
    /// The format style for angle measurements.
    static var angle: Self {
        .measurement(width: .narrow, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0)))
    }
}

private extension FormatStyle where Self == FloatingPointFormatStyle<Double>.Percent {
    /// The format style for rounding percents.
    static var rounded: Self {
        .percent.rounded(rule: .up, increment: 0.1)
    }
}
