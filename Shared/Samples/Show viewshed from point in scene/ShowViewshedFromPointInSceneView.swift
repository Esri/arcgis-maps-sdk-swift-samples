// Copyright 2022 Esri
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

struct ShowViewshedFromPointInSceneView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// A Boolean value indicating whether the settings sheet is being shown or not.
    @State private var isShowingSettings = false
    
    var body: some View {
        SceneView(scene: model.scene, analysisOverlays: [model.analysisOverlay])
            .onSingleTapGesture { _, scenePoint in
                if let scenePoint {
                    model.viewshed.location = scenePoint
                    model.locationZ = scenePoint.z!
                }
            }
            .overlay(alignment: .top) {
                Text("Tap on the scene to move the viewshed")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(.thinMaterial, ignoresSafeAreaEdges: .horizontal)
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button("Viewshed Settings") {
                        isShowingSettings = true
                    }
                    .sheet(isPresented: $isShowingSettings, detents: [.medium], dragIndicatorVisibility: .visible) {
                        ViewshedSettingsView(model: model)
                    }
                }
            }
    }
}

#Preview {
    NavigationView {
        ShowViewshedFromPointInSceneView()
    }
}
