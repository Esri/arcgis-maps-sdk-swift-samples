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
        
        /// An array of snap source layer names and their source settings.
        @State private var snapSources: [(layerName: String, sourceSettings: SnapSourceSettings)] = []
        
        /// An array of Boolean values for each snap source enabled states.
        @State private var snapSourceEnabledStates: [Bool] = []
        
        var body: some View {
            Form {
                Section("Snap Source") {
                    Toggle("Snapping", isOn: $snappingEnabled)
                        .onChange(of: snappingEnabled) { newValue in
                            model.geometryEditor.snapSettings.isEnabled = newValue
                        }
                }
                
                Section("Layer Settings") {
                    ForEach(0 ..< snapSources.count, id: \.self) { index in
                        Toggle(snapSources[index].layerName, isOn: $snapSourceEnabledStates[index])
                            .onChange(of: snapSourceEnabledStates[index]) { newValue in
                                snapSources[index].sourceSettings.isEnabled = newValue
                            }
                    }
                }
            }
            .onAppear {
                // Enables snapping in the current geometry editor.
                model.geometryEditor.snapSettings.isEnabled = true
                snappingEnabled = model.geometryEditor.snapSettings.isEnabled
                
                // Creates an array from snap source layers with their
                // layer name and source settings.
                snapSources = model.geometryEditor.snapSettings.sourceSettings.compactMap { sourceSettings in
                    if let layer = sourceSettings.source as? FeatureLayer {
                        return (layer.name, sourceSettings)
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
