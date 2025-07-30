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

extension SnapGeometryEditsView {
    struct SnapSettingsView: View {
        /// The action to dismiss the settings sheet.
        @Environment(\.dismiss) private var dismiss: DismissAction
        
        /// The view model for the sample.
        @ObservedObject var model: GeometryEditorModel
        
        /// A Boolean value indicating whether snapping is enabled
        /// for the geometry editor.
        @State private var snappingEnabled = false
        
        /// A Boolean value indicating whether the geometry editor snaps to geometry guides.
        @State private var snapsToGeometryGuides = false
        
        /// A Boolean value indicating whether the geometry editor snaps to features and graphics.
        @State private var snapsToFeatures = false
        
        /// An array of snap source names and their source settings.
        @State private var snapSources: [(name: String, sourceSettings: SnapSourceSettings)] = []
        
        /// An array of Boolean values for each snap source enabled states.
        @State private var snapSourceEnabledStates: [Bool] = []
        
        var body: some View {
            Form {
                Section("Geometry Editor Snapping") {
                    Toggle("Snapping", isOn: $snappingEnabled)
                        .onChange(of: snappingEnabled) {
                            model.geometryEditor.snapSettings.isEnabled = snappingEnabled
                        }
                    
                    Toggle("Geometry Guides", isOn: $snapsToGeometryGuides)
                        .onChange(of: snapsToGeometryGuides) {
                            model.geometryEditor.snapSettings.snapsToGeometryGuides = snapsToGeometryGuides
                        }
                        .disabled(!snappingEnabled)
                    
                    Toggle("Feature Snapping", isOn: $snapsToFeatures)
                        .onChange(of: snapsToFeatures) {
                            model.geometryEditor.snapSettings.snapsToFeatures = snapsToFeatures
                        }
                        .disabled(!snappingEnabled)
                }
                
                Section("Individual Source Snapping") {
                    ForEach(0 ..< snapSources.count, id: \.self) { index in
                        Toggle(snapSources[index].name, isOn: $snapSourceEnabledStates[index])
                            .onChange(of: snapSourceEnabledStates[index]) {
                                snapSources[index].sourceSettings.isEnabled = snapSourceEnabledStates[index]
                            }
                    }
                }
                .disabled(!snappingEnabled || !snapsToFeatures)
            }
            .navigationTitle("Snap Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                snappingEnabled = model.geometryEditor.snapSettings.isEnabled
                snapsToGeometryGuides = model.geometryEditor.snapSettings.snapsToGeometryGuides
                snapsToFeatures = model.geometryEditor.snapSettings.snapsToFeatures
                
                // Creates an array from snap source layers or graphics overlays
                // with their name and source settings.
                snapSources = model.geometryEditor.snapSettings.sourceSettings.compactMap { sourceSettings in
                    if let layer = sourceSettings.source as? FeatureLayer {
                        return (layer.name, sourceSettings)
                    } else if let graphicsOverlay = sourceSettings.source as? GraphicsOverlay {
                        return (graphicsOverlay.id, sourceSettings)
                    } else {
                        return nil
                    }
                }
                
                // Initializes the enabled states from the snap sources.
                snapSourceEnabledStates = snapSources.map { _, sourceSettings in
                    return sourceSettings.isEnabled
                }
            }
        }
    }
}
