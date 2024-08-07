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

struct SnapGeometryEditsView: View {
    /// The map to display in the view.
    @State private var map: Map = {
        let map = Map(
            item: PortalItem(
                portal: .arcGISOnline(connection: .anonymous),
                // A stripped down Naperville water distribution network web map.
                id: PortalItem.ID("b95fe18073bc4f7788f0375af2bb445e")!
            )
        )
        // Snapping is used to maintain data integrity between different sources
        // of data when editing, so full resolution is needed for valid snapping.
        map.loadSettings.featureTilingMode = .enabledWithFullResolutionWhenSupported
        return map
    }()
    
    /// The model that is required by the geometry editor menu.
    @StateObject private var model = GeometryEditorModel()
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    /// A Boolean value indicating whether all the snap sources on the map view are loaded.
    @State private var snapSourcesAreLoaded = false
    
    /// A Boolean value indicating whether the snap settings are presented.
    @State private var showsSnapSettings = false
    
    var body: some View {
        MapView(map: map, graphicsOverlays: [model.geometryOverlay])
            .geometryEditor(model.geometryEditor)
            .onDrawStatusChanged { drawStatus in
                guard !snapSourcesAreLoaded else { return }
                snapSourcesAreLoaded = drawStatus == .completed
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
                    .popover(isPresented: $showsSnapSettings) {
                        NavigationStack {
                            // Various snapping settings for a geometry editor.
                            SnapSettingsView(model: model)
                        }
                        .presentationDetents([.fraction(0.6)])
                        .frame(idealWidth: 320, idealHeight: 380)
                    }
                    .disabled(!snapSourcesAreLoaded)
                }
            }
            .errorAlert(presentingError: $error)
    }
}

#Preview {
    NavigationStack {
        SnapGeometryEditsView()
    }
}
