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

struct GroupLayersTogetherView: View {
    /// A scene with an imagery basemap and a world elevations source.
    @State private var scene: ArcGIS.Scene = {
        let scene = Scene(basemapStyle: .arcGISImagery)
        
        // Add base surface to the scene for elevation data.
        let elevationSource = ArcGISTiledElevationSource(url: .worldElevationService)
        let surface = Surface()
        surface.addElevationSource(elevationSource)
        scene.baseSurface = surface
        return scene
    }()
    
    /// The current viewpoint of the scene view.
    @State private var viewpoint: Viewpoint?
    
    /// A Boolean value that indicates whether the layers sheet is showing.
    @State private var isShowingLayersSheet = false
    
    var body: some View {
        SceneView(scene: scene, viewpoint: viewpoint)
            .onViewpointChanged(kind: .centerAndScale) { viewpoint = $0 }
            .task {
                // Add group layers to the scene as operational layers.
                scene.addOperationalLayers([makeProjectAreaGroupLayer(), makeBuildingsGroupLayer()])
                
                // Ensure all group layers' childlayers are loaded.
                for groupLayer in scene.operationalLayers as! [GroupLayer] {
                    await groupLayer.layers.load()
                }
                
                // Set the scene's viewpoint with the extent of the project area group layer.
                if let extent = scene.operationalLayers.first?.fullExtent {
                    let camera = Camera(lookingAt: extent.center, distance: 700, heading: 0, pitch: 60, roll: 0)
                    viewpoint = Viewpoint(latitude: .nan, longitude: .nan, scale: .nan, camera: camera)
                }
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    layersButton
                }
            }
    }
    
    /// The button that brings up the layers sheet.
    @ViewBuilder private var layersButton: some View {
        let button = Button("Layers") {
            isShowingLayersSheet = true
        }
        
        if #available(iOS 16, *) {
            button
                .popover(isPresented: $isShowingLayersSheet, arrowEdge: .bottom) {
                    layersList
                        .presentationDetents([.fraction(0.5)])
#if targetEnvironment(macCatalyst)
                        .frame(minWidth: 300, minHeight: 270)
#else
                        .frame(minWidth: 320, minHeight: 390)
#endif
                }
        } else {
            button
                .sheet(isPresented: $isShowingLayersSheet, detents: [.medium]) {
                    layersList
                }
        }
    }
    
    /// The list of group layers and their child layers that are currently added to the map.
    private var layersList: some View {
        NavigationView {
            List {
                ForEach(scene.operationalLayers as! [GroupLayer], id: \.name) { groupLayer in
                    GroupLayerListView(groupLayer: groupLayer)
                }
            }
            .navigationTitle("Layers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isShowingLayersSheet = false
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .frame(idealWidth: 320, idealHeight: 428)
    }
}

extension GroupLayersTogetherView {
    /// Creates the project area group layer from individual child layers.
    /// - Returns: A `GroupLayer` object.
    private func makeProjectAreaGroupLayer() -> GroupLayer {
        // Create a group layer and set its name.
        let groupLayer = GroupLayer()
        groupLayer.name = "Project area group"
        
        // Create a scene layer for the trees.
        let treesLayer = ArcGISSceneLayer(url: .trees)
        
        // Create a feature layer for the pathways.
        let pathwaysTable = ServiceFeatureTable(url: .pathways)
        let pathwaysLayer = FeatureLayer(featureTable: pathwaysTable)
        pathwaysLayer.sceneProperties.altitudeOffset = 1
        pathwaysLayer.sceneProperties.surfacePlacement = .relative
        
        // Create a feature layer for the project area.
        let projectAreaTable = ServiceFeatureTable(url: .projectArea)
        let projectAreaLayer = FeatureLayer(featureTable: projectAreaTable)
        
        // Add the scene and feature layers as children of the group layer.
        groupLayer.addLayers([treesLayer, pathwaysLayer, projectAreaLayer])
        return groupLayer
    }
    
    /// Creates the buildings group layer from individual child layers.
    /// - Returns: A `GroupLayer` object.
    private func makeBuildingsGroupLayer() -> GroupLayer {
        // Create a group layer and set its name.
        let groupLayer = GroupLayer()
        groupLayer.name = "Buildings group"
        
        // Create layers for the buildings.
        let buildingsALayer = ArcGISSceneLayer(url: .buildingsA)
        let buildingsBLayer = ArcGISSceneLayer(url: .buildingsB)
        
        // Add the scene layers as children of the group layer.
        groupLayer.addLayers([buildingsALayer, buildingsBLayer])
        
        // Set the visibility mode to exclusive so only one sublayer can be visible
        // at a time.
        groupLayer.visibilityMode = .exclusive
        return groupLayer
    }
}

private extension URL {
    /// A URL for a world elevation service from Terrain3D ArcGIS REST service.
    static var worldElevationService: URL {
        URL(string: "https://elevation3d.arcgis.com/arcgis/rest/services/WorldElevation3D/Terrain3D/ImageServer")!
    }
    
    /// A URL for the tress scene service.
    static var trees: URL {
        URL(string: "https://tiles.arcgis.com/tiles/P3ePLMYs2RVChkJx/arcgis/rest/services/DevA_Trees/SceneServer")!
    }
    
    /// A URL for the pathways feature service.
    static var pathways: URL {
        URL(string: "https://services.arcgis.com/P3ePLMYs2RVChkJx/arcgis/rest/services/DevA_Pathways/FeatureServer/1")!
    }
    
    /// A URL for the project area feature service.
    static var projectArea: URL {
        URL(string: "https://services.arcgis.com/P3ePLMYs2RVChkJx/arcgis/rest/services/DevelopmentProjectArea/FeatureServer/0")!
    }
    
    /// A URL for the buildings A scene service.
    static var buildingsA: URL {
        URL(string: "https://tiles.arcgis.com/tiles/P3ePLMYs2RVChkJx/arcgis/rest/services/DevA_BuildingShells/SceneServer")!
    }
    
    /// A URL for the buildings B scene service.
    static var buildingsB: URL {
        URL(string: "https://tiles.arcgis.com/tiles/P3ePLMYs2RVChkJx/arcgis/rest/services/DevB_BuildingShells/SceneServer")!
    }
}

#Preview {
    NavigationView {
        GroupLayersTogetherView()
    }
}
