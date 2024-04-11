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
import ArcGISToolkit
import SwiftUI

struct AugmentRealityToCollectDataView: View {
    /// The view model for this sample.
    @StateObject private var model = Model()
    /// The status text displayed to the user.
    @State private var statusText = "Tap to create a feature"
    /// A Boolean value indicating whether a feature can be added .
    @State private var canAddFeature = false
    /// A Boolean value indicating whether the tree health action sheet is presented.
    @State private var treeHealthSheetIsPresented = false
    /// The error shown in the error alert.
    @State private var error: Error?
    
    var body: some View {
        VStack(spacing: 0) {
            WorldScaleSceneView { _ in
                SceneView(scene: model.scene, graphicsOverlays: [model.graphicsOverlay])
            }
            .calibrationButtonAlignment(.bottomLeading)
            .onCalibratingChanged { newCalibrating in
                model.scene.baseSurface.opacity = newCalibrating ? 0.5 : 0
            }
            .onSingleTapGesture { _, scenePoint in
                model.graphicsOverlay.removeAllGraphics()
                canAddFeature = true
                
                // Add feature graphic.
                model.graphicsOverlay.addGraphic(Graphic(geometry: scenePoint))
                statusText = "Placed relative to ARKit plane"
            }
            .task {
                do {
                    try await model.featureTable.load()
                } catch {
                    self.error = error
                }
            }
            .overlay(alignment: .top) {
                Text(statusText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(8)
                    .background(.regularMaterial, ignoresSafeAreaEdges: .horizontal)
            }
            Divider()
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button {
                    treeHealthSheetIsPresented = true
                } label: {
                    Image(systemName: "plus")
                        .imageScale(.large)
                }
                .disabled(!canAddFeature)
                .confirmationDialog(
                    "Add Tree",
                    isPresented: $treeHealthSheetIsPresented,
                    titleVisibility: .visible,
                    actions: {
                        ForEach(TreeHealth.allCases, id: \.self) { treeHealth in
                            Button(treeHealth.label) {
                                statusText = "Adding feature"
                                Task {
                                    do {
                                        try await model.addTree(health: treeHealth)
                                        statusText = "Tap to create a feature"
                                        canAddFeature = false
                                    } catch {
                                        self.error = error
                                    }
                                }
                            }
                        }
                    }, message: {
                        Text("How healthy is this tree?")
                    })
            }
        }
        .errorAlert(presentingError: $error)
    }
}

private extension AugmentRealityToCollectDataView {
    @MainActor
    class Model: ObservableObject {
        /// A scene with an imagery basemap.
        @State var scene: ArcGIS.Scene = {
            // Creates an elevation source from Terrain3D REST service.
            let elevationServiceURL = URL(
                string: "https://elevation3d.arcgis.com/arcgis/rest/services/WorldElevation3D/Terrain3D/ImageServer"
            )!
            let elevationSource = ArcGISTiledElevationSource(url: elevationServiceURL)
            let surface = Surface()
            surface.addElevationSource(elevationSource)
            surface.backgroundGrid.isVisible = false
            // Allow camera to go beneath the surface.
            surface.navigationConstraint = .unconstrained
            let scene = Scene(basemapStyle: .arcGISImagery)
            scene.baseSurface = surface
            scene.baseSurface.opacity = 0
            return scene
        }()
        /// The AR tree survey service feature table.
        let featureTable = ServiceFeatureTable(
            url: URL(string: "https://services2.arcgis.com/ZQgQTuoyBrtmoGdP/arcgis/rest/services/AR_Tree_Survey/FeatureServer/0")!
        )
        /// The graphics overlay which shows marker symbols.
        @State var graphicsOverlay: GraphicsOverlay = {
            let graphicsOverlay = GraphicsOverlay()
            let tappedPointSymbol = SimpleMarkerSceneSymbol(
                style: .diamond,
                color: .orange,
                height: 0.5,
                width: 0.5,
                depth: 0.5,
                anchorPosition: .center
            )
            graphicsOverlay.renderer = SimpleRenderer(symbol: tappedPointSymbol)
            graphicsOverlay.sceneProperties.surfacePlacement = .absolute
            return graphicsOverlay
        }()
        /// The selected tree health for the new feature.
        @State private var treeHealth: TreeHealth?
        
        init() {
            let featureLayer = FeatureLayer(featureTable: featureTable)
            featureLayer.sceneProperties.surfacePlacement = .absolute
            scene.addOperationalLayer(featureLayer)
        }
        
        /// Adds a feature to represent a tree to the tree survey service feature table.
        /// - Parameter treeHealth: The health of the tree.
        func addTree(health: TreeHealth) async throws {
            guard let featureGraphic = graphicsOverlay.graphics.first,
                  let featurePoint = featureGraphic.geometry as? Point else { return }
            
            // Create attributes for the new feature.
            let featureAttributes: [String: Any] = [
                "Health": health.rawValue,
                "Height": 3.2,
                "Diameter": 1.2
            ]
            
            if let newFeature = featureTable.makeFeature(
                attributes: featureAttributes,
                geometry: featurePoint
            ) as? ArcGISFeature {
                do {
                    // Add the feature to the feature table.
                    try await featureTable.add(newFeature)
                    _ = try await featureTable.applyEdits()
                } catch {
                    throw error
                }
                newFeature.refresh()
            }
            
            graphicsOverlay.removeAllGraphics()
        }
    }
}

private extension AugmentRealityToCollectDataView {
    /// The health of a tree.
    enum TreeHealth: Int16, CaseIterable, Equatable {
        /// The tree is dead.
        case dead = 0
        /// The tree is distressed.
        case distressed = 5
        /// The tree is healthy.
        case healthy = 10
        
        /// A human-readable label for each kind of tree health.
        var label: String {
            switch self {
            case .dead: "Dead"
            case .distressed: "Distressed"
            case .healthy: "Healthy"
            }
        }
    }
}

#Preview {
    AugmentRealityToCollectDataView()
}
