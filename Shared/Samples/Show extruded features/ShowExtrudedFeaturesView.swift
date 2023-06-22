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

import SwiftUI
import ArcGIS

struct ShowExtrudedFeaturesView: View {
    /// A scene with a topographic basemap centered on the US.
    @State private var scene: ArcGIS.Scene = {
        let scene = Scene(basemapStyle: .arcGISTopographic)
        
        // Set the scene view's viewpoint specified by the camera position.
        let distance = 12_940_924.0
        let point = Point(x: -99.659448, y: 20.513652, z: distance, spatialReference: .wgs84)
        let camera = Camera(lookingAt: point, distance: 0, heading: 0, pitch: 15, roll: 0)
        scene.initialViewpoint = Viewpoint(center: point, scale: distance, camera: camera)
        
        return scene
    }()
    
    /// The renderer of the feature layer.
    @State private var renderer: SimpleRenderer = {
        // Setup the symbols used to display the features (US states) from the table.
        let lineSymbol = SimpleLineSymbol(style: .solid, color: .blue, width: 1.0)
        let fillSymbol = SimpleFillSymbol(style: .solid, color: .blue, outline: lineSymbol)
        return SimpleRenderer(symbol: fillSymbol)
    }()
    
    /// The population statistic selection of the picker.
    @State private var statisticSelection = Statistic.totalPopulation
    
    /// A Boolean value indicating whether to show an error alert.
    @State private var isShowingAlert = false
    
    /// The error shown in the alert.
    @State private var error: Error? {
        didSet { isShowingAlert = error != nil }
    }
    
    var body: some View {
        VStack {
            SceneView(scene: scene)
                .task {
                    do {
                        // Create service feature table from US census feature service.
                        let featureTable = ServiceFeatureTable(url: .censusMapStates)
                        try await featureTable.load()
                        
                        // Create feature layer from service feature table.
                        let featureLayer = FeatureLayer(featureTable: featureTable)
                        
                        // Feature layer must be rendered dynamically for extrusion to work.
                        featureLayer.renderingMode = .dynamic
                        
                        // Set the renderer scene properties.
                        renderer.sceneProperties.extrusionMode = .baseHeight
                        renderer.sceneProperties.extrusionExpression = Statistic.totalPopulation.extrusionExpression
                        
                        // Set the renderer on the layer and add the layer to the scene.
                        featureLayer.renderer = renderer
                        scene.addOperationalLayer(featureLayer)
                    } catch {
                        // Present error if the feature table fails to load.
                        self.error = error
                    }
                }
                .alert(isPresented: $isShowingAlert, presentingError: error)
            
            // Unit system picker.
            Picker("", selection: $statisticSelection) {
                Text("Total Population").tag(Statistic.totalPopulation)
                Text("Population Density").tag(Statistic.populationDensity)
            }
            .pickerStyle(.segmented)
            .padding()
            .onChange(of: statisticSelection) { newValue in
                featureLayer.renderer?.sceneProperties.extrusionExpression = newValue.extrusionExpression
                }
            }
        }
    }
}

private extension ShowExtrudedFeaturesView {
    /// A enum for the different population statistics.
    enum Statistic: Int {
        case totalPopulation
        case populationDensity
        
        /// The extrusion expression for the statistic.
        var extrusionExpression: String {
            switch self {
            case .totalPopulation:
                return "[POP2007] / 10"
            case .populationDensity:
                // The offset makes the extrusion look better over Alaska.
                let offset = 100_000
                return "([POP07_SQMI] * 5000) + \(offset)"
            }
        }
    }
}

private extension URL {
    /// The States layer of the Census Map Service.
    static var censusMapStates: URL {
        URL(string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/Census/MapServer/3")!
    }
}
