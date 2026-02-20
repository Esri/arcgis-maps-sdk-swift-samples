// Copyright 2026 Esri
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

struct ConfigureSceneEnvironmentView: View {
    /// A local scene with a scene layer in Sante Fe.
    @State private var scene = Scene(url: URL(string: "https://www.arcgis.com/home/item.html?id=fcebd77958634ac3874bbc0e6b0677a4")!)!
    /// The environment for the scene.
    @State private var environment: SceneEnvironment?
    /// A Boolean value indicating if the settings are visible or not.
    @State private var settingsAreVisible = false
    
    var body: some View {
        LocalSceneView(scene: scene)
            .task {
                try? await scene.load()
                environment = scene.environment
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    if let environment {
                        Button("Settings", systemImage: "gear") {
                            settingsAreVisible = true
                        }
                        .popover(isPresented: $settingsAreVisible) { [environment] in
                            EnvironmentSettingsView(environment: environment)
                                .frame(idealWidth: 400, idealHeight: 500)
                                .presentationCompactAdaptation(.popover)
                        }
                    } else {
                        ProgressView()
                    }
                }
            }
    }
}

private struct EnvironmentSettingsView: View {
    /// The environment that backs the settings.
    let environment: SceneEnvironment
    
    @Environment(\.dismiss) private var dismiss
    
    // Sky properties.
    
    /// A Boolean value that indicates if the atmosphere is enabled.
    @State private var atmosphereIsEnabled = false
    /// A Boolean value that indicates if stars are enabled.
    @State private var starsAreEnabled = false
    
    // Background color properties.
    
    /// The background color for the environment.
    @State private var backgroundColor: Color = .clear
    
    // Lighting properties.
    
    /// The lighting type that is selected in the picker.
    @State private var lightingType: LightingType = .sun
    /// A Boolean value that indicates if direct shadows are enabled.
    @State private var directShadowsAreEnabled = false
    
    // Time slider properties.
    
    /// The simulated date for the sun lighting.
    @State private var simulatedDate: Date = .now
    /// The number seconds in the day that is driving the time slider.
    @State private var dateSecond: TimeInterval = 0
    /// The start of the day used for the time slider.
    @State private var startOfDay: Date = .now
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Sky") {
                    Toggle("Atmosphere", isOn: $atmosphereIsEnabled)
                        .onChange(of: atmosphereIsEnabled) {
                            environment.atmosphereIsEnabled = atmosphereIsEnabled
                        }
                    
                    if lightingType == .sun {
                        Toggle("Stars", isOn: $starsAreEnabled)
                            .onChange(of: starsAreEnabled) {
                                environment.starsAreEnabled = starsAreEnabled
                            }
                            // The stars can't be seen without atmosphere disabled.
                            // So we should only enable the stars toggle when
                            // atmosphere is enabled.
                            .disabled(atmosphereIsEnabled)
                    }
                }
                Section("Background") {
                    ColorPicker("Color", selection: $backgroundColor, supportsOpacity: false)
                        .onChange(of: backgroundColor) {
                            setBackgroundColor()
                        }
                }
                Section("Lighting") {
                    Picker("Lighting Type", selection: $lightingType.animation()) {
                        ForEach(LightingType.allCases, id: \.self) { lightingType in
                            Text(lightingType.label)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: lightingType) {
                        environment.lighting = makeLighting(lightingType: lightingType)
                    }
                    
                    Toggle("Shadows", isOn: $directShadowsAreEnabled)
                        .onChange(of: directShadowsAreEnabled) {
                            environment.lighting.directShadowsAreEnabled = directShadowsAreEnabled
                        }
                    
                    // The time slider only applies to sun lighting
                    // so we don't need to show it if virtual lighting
                    // is selected.
                    if lightingType == .sun {
                        Slider(value: $dateSecond, in: .dateSecondValues) {
                            Text("Time")
                        } minimumValueLabel: {
                            Image(systemName: "sun.max.fill")
                        } maximumValueLabel: {
                            Image(systemName: "moon.fill")
                        }
                        .onChange(of: dateSecond) {
                            sliderValueChanged(toValue: dateSecond)
                        }
                        .onChange(of: simulatedDate) {
                            (environment.lighting as! SunLighting).simulatedDate = simulatedDate
                        }
                    }
                }
            }
            .onAppear {
                // Update local properties with current environment values.
                atmosphereIsEnabled = environment.atmosphereIsEnabled
                starsAreEnabled = environment.starsAreEnabled
                backgroundColor = Color(environment.backgroundColor)
                
                let lighting = environment.lighting
                directShadowsAreEnabled = environment.lighting.directShadowsAreEnabled
                
                if let sunLighting = lighting as? SunLighting {
                    lightingType = .sun
                   
                    // Calculate the seconds from the start of the
                    // day to update the slider to the correct value.
                    let simulatedDate = sunLighting.simulatedDate
                    startOfDay = Calendar.current.startOfDay(for: simulatedDate)
                    dateSecond = simulatedDate.timeIntervalSince(startOfDay)
                } else {
                    lightingType = .virtual
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    /// Sets the background color.
    ///
    /// We turn off the atmosphere and stars if the user sets the background color so they
    /// can see it right away. The background color is rendered behind the atmosphere and stars
    /// so we need to turn them both off to see the background color.
    private func setBackgroundColor() {
        if backgroundColor != Color(environment.backgroundColor) {
            // Set the background color.
            environment.backgroundColor = UIColor(backgroundColor)
            
            // We turn off the atmosphere and stars if the user
            // expliclity set the background color so they can see the
            // new background color they set.
            atmosphereIsEnabled = false
            starsAreEnabled = false
        }
    }
    
    private enum LightingType: CaseIterable {
        case virtual
        case sun
        
        var label: String {
            switch self {
            case .virtual: "Virtual"
            case .sun: "Sun"
            }
        }
    }
    
    private func makeLighting(lightingType: LightingType) -> SceneLighting {
        return switch lightingType {
        case .virtual:
            VirtualLighting(
                directShadowsAreEnabled: directShadowsAreEnabled
            )
        case .sun:
            SunLighting(
                simulatedDate: simulatedDate,
                directShadowsAreEnabled: directShadowsAreEnabled
            )
        }
    }
    
    /// Handles the slider value changed event and sets the simulated date.
    /// - Parameter value: The slider's value.
    private func sliderValueChanged(toValue value: TimeInterval) {
        let dateComponents = DateComponents(second: Int(value))
        let date = Calendar.current.date(byAdding: dateComponents, to: startOfDay)!
        simulatedDate = date
    }
}

private extension ClosedRange where Bound == TimeInterval {
    /// The range of possible date second values.
    /// The range is 28,800 to 79,200 seconds in this example,
    /// which means 8am to 10pm.
    static var dateSecondValues: Self { 28_800...79_200 }
}
