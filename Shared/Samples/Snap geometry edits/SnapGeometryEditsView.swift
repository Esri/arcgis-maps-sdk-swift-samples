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

/// A view that shows how to interact with the geometry editor.
struct SnapGeometryEditsView: View {
    /// The map to display in the view.
    @State private var map: Map = {
        let map = Map(
            item: PortalItem(
                portal: .arcGISOnline(connection: .anonymous),
                // A stripped down Naperville water distribution network webmap.
                id: PortalItem.ID("b95fe18073bc4f7788f0375af2bb445e")!
            )
        )
        // Snapping is used to maintain data integrity between different sources
        // of data when editing, so full resolution is needed for valid snapping.
        map.loadSettings.featureTilingMode = .enabledWithFullResolutionWhenSupported
        return map
    }()
    
    /// The model that is required by the geometry editor menu.
    @StateObject private var model = GeometryEditorMenuModel(
        geometryEditor: GeometryEditor(),
        graphicsOverlay: GraphicsOverlay(renderingMode: .dynamic)
    )
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    /// A Boolean value indicating whether all the operational layers are loaded.
    @State private var layersAreLoaded = false
    
    /// A Boolean value indicating whether the snap settings are presented.
    @State private var showsSnapSettings = false
    
    var body: some View {
        MapView(map: map, graphicsOverlays: [model.graphicsOverlay])
            .geometryEditor(model.geometryEditor)
            .task {
                do {
                    // Load every layer in the webmap.
                    for layer in map.operationalLayers {
                        try await layer.load()
                    }
                    layersAreLoaded = true
                } catch {
                    self.error = error
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Spacer()
                    
                    GeometryEditorMenu(model: model)
                    
                    Spacer()
                    
                    Button("Snap Settings") {
                        do {
                            try model.geometryEditor.snapSettings.syncSourceSettings()
                            showsSnapSettings = true
                        } catch {
                            self.error = error
                        }
                    }
                    .sheet(isPresented: $showsSnapSettings, detents: [.medium]) {
                        SnapSettingsView(model: model)
                    }
                    .disabled(!layersAreLoaded)
                }
            }
            .errorAlert(presentingError: $error)
    }
}

extension SnapGeometryEditsView {
    private struct SnapSettingsView: View {
        /// The action to dismiss the settings sheet.
        @Environment(\.dismiss) private var dismiss: DismissAction
        
        /// The view model for the sample.
        @ObservedObject var model: GeometryEditorMenuModel
        
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

#Preview {
    NavigationView {
        SnapGeometryEditsView()
    }
}
