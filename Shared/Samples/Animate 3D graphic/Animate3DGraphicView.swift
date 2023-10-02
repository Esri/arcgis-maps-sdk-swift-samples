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
    
    var body: some View {
        SceneView(
            scene: model.scene,
            cameraController: model.cameraController,
            graphicsOverlays: [model.sceneGraphicsOverlay]
        )
        .overlay {
            HStack {
                /// The map view that tracks the plane on a 2D map.
                VStack {
                    Spacer()
                    MapView(map: model.map, viewpoint: model.viewpoint, graphicsOverlays: [model.mapGraphicsOverlay])
                        .interactionModes([])
                        .attributionBarHidden(true)
                        .frame(width: 100, height: 100)
                        .cornerRadius(10)
                        .shadow(radius: 3)
                }
                .padding(.bottom)
                
                Spacer()
                
                /// The stats of the current position of the plane.
                VStack {
                    VStack {
                        StatRow(title: "Altitude", value: model.animation.currentFrame.altitude.formatted(.length))
                        StatRow(title: "Heading", value: model.animation.currentFrame.heading.formatted(.angle))
                        StatRow(title: "Pitch", value: model.animation.currentFrame.pitch.formatted(.angle))
                        StatRow(title: "Roll", value: model.animation.currentFrame.roll.formatted(.angle))
                    }
                    .frame(width: 170, height: 100)
                    .background(Color.white.opacity(0.5))
                    .cornerRadius(10)
                    .shadow(radius: 3)
                    Spacer()
                }
            }
            .padding()
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                /// The mission selection menu.
                Menu("Mission") {
                    Picker("Mission", selection: $model.mission) {
                        ForEach(Mission.allCases, id: \.self) { mission in
                            Text(mission.label)
                        }
                        .pickerStyle(.inline)
                    }
                }
                
                Spacer()
                
                /// The play/pause button.
                Button {
                    model.animation.isPlaying ? model.animation.stop() : model.startAnimation()
                } label: {
                    Image(systemName: model.animation.isPlaying ? "pause.fill" : "play.fill")
                }
                
                Spacer()
                
                Button("Camera") {
                }
            }
        }
        .onDisappear {
            model.animation.stop()
        }
    }
}

private extension Animate3DGraphicView {
    /// A view for displaying a statistic in a row.
    struct StatRow: View {
        /// The title of the statistic.
        var title: String
        /// The value of the statistic.
        var value: String
        
        var body: some View {
            HStack {
                Text(title)
                Spacer()
                Text(value)
            }
            .padding([.leading, .trailing])
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
