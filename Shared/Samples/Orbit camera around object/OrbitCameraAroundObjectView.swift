// Copyright 2024 Esri
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

struct OrbitCameraAroundObjectView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// The camera view selection.
    @State private var selectedCameraView = CameraView.center
    
    /// A Boolean value indicating whether the settings sheet is presented.
    @State private var settingsSheetIsPresented = false
    
    /// A Boolean value indicating whether scene interaction is disabled.
    @State private var sceneIsDisabled = false
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    var body: some View {
        SceneView(
            scene: model.scene,
            cameraController: model.cameraController,
            graphicsOverlays: [model.graphicsOverlay]
        )
        .disabled(sceneIsDisabled)
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                cameraViewPicker
                settingsButton
            }
        }
        .errorAlert(presentingError: $error)
    }
    
    /// The picker for selecting the camera view.
    private var cameraViewPicker: some View {
        Picker("Camera View", selection: $selectedCameraView) {
            Text("Center").tag(CameraView.center)
            Text("Cockpit").tag(CameraView.cockpit)
        }
        .pickerStyle(.segmented)
        .task(id: selectedCameraView) {
            // Move the camera to the new view selection.
            do {
                // Disable scene interaction while the camera is moving.
                sceneIsDisabled = true
                defer { sceneIsDisabled = false }
                
                switch selectedCameraView {
                case .center:
                    try await model.moveToPlaneView()
                case .cockpit:
                    try await model.moveToCockpit()
                }
            } catch {
                self.error = error
            }
        }
    }
    
    /// The button that brings up the settings sheet.
    @ViewBuilder private var settingsButton: some View {
        let button = Button("Settings") {
            settingsSheetIsPresented = true
        }
        let settingsContent = SettingsView(model: model)
        
        if #available(iOS 16, *) {
            button
                .popover(isPresented: $settingsSheetIsPresented, arrowEdge: .bottom) {
                    settingsContent
                        .presentationDetents([.fraction(0.5)])
#if targetEnvironment(macCatalyst)
                        .frame(minWidth: 300, minHeight: 270)
#else
                        .frame(minWidth: 320, minHeight: 390)
#endif
                }
        } else {
            button
                .sheet(isPresented: $settingsSheetIsPresented, detents: [.medium]) {
                    settingsContent
                }
        }
    }
}

private extension OrbitCameraAroundObjectView {
    /// The camera and plane settings for the sample.
    struct SettingsView: View {
        /// The view model for the sample.
        @ObservedObject var model: Model
        
        /// The action to dismiss the view.
        @Environment(\.dismiss) private var dismiss: DismissAction
        
        /// The heading offset of the camera controller.
        @State private var cameraHeading = Measurement<UnitAngle>(value: 0, unit: .degrees)
        
        /// The pitch of the plane in the scene.
        @State private var planePitch = Measurement<UnitAngle>(value: 0, unit: .degrees)
        
        /// A Boolean value indicating whether the camera distance is interactive.
        @State private var cameraDistanceIsInteractive = false
        
        var body: some View {
            NavigationView {
                List {
                    VStack {
                        Text("Camera Heading")
                            .badge(
                                Text(cameraHeading, format: .degrees)
                            )
                        
                        Slider(value: $cameraHeading.value, in: -45...45)
                            .onChange(of: cameraHeading.value) { newValue in
                                model.cameraController.cameraHeadingOffset = newValue
                            }
                    }
                    
                    VStack {
                        Text("Plane Pitch")
                            .badge(
                                Text(planePitch, format: .degrees)
                            )
                        
                        Slider(value: $planePitch.value, in: -90...90)
                            .onChange(of: planePitch.value) { newValue in
                                model.planeGraphic.setAttributeValue(newValue, forKey: "PITCH")
                            }
                    }
                    
                    Toggle("Allow Camera Distance Interaction", isOn: $cameraDistanceIsInteractive)
                        .toggleStyle(.switch)
                        .disabled(model.cameraController.autoPitchIsEnabled)
                        .onChange(of: cameraDistanceIsInteractive) { newValue in
                            model.cameraController.cameraDistanceIsInteractive = newValue
                        }
                }
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
            .navigationViewStyle(.stack)
            .onAppear {
                planePitch.value = model.planeGraphic.attributes["PITCH"] as! Double
                cameraHeading.value = model.cameraController.cameraHeadingOffset
                cameraDistanceIsInteractive = model.cameraController.cameraDistanceIsInteractive
            }
        }
    }
    
    /// An enumeration representing a camera controller view.
    enum CameraView: CaseIterable {
        /// The view with the plane centered.
        case center
        /// The view from the plane's cockpit.
        case cockpit
    }
}

private extension FormatStyle where Self == Measurement<UnitAngle>.FormatStyle {
    /// The format style for degrees.
    static var degrees: Self {
        .measurement(
            width: .narrow,
            usage: .asProvided,
            numberFormatStyle: .number.precision(.fractionLength(0))
        )
    }
}
