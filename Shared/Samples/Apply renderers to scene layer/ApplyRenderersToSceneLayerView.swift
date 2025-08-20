// Copyright 2025 Esri
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

struct ApplyRenderersToSceneLayerView: View {
    /// The error shown in the error alert.
    @State private var error: (any Error)?
    
    @State private var rendererSelection: RendererType = .none
    
    @State private var renderer: Renderer?
    
    // Store the scene layer so you can access it later
    private let sceneLayer = ArcGISSceneLayer(url: .world)
    
    @State private var scene: ArcGIS.Scene = {
        var scene = Scene(basemapStyle: .arcGISLightGray)
        let elevationSource = ArcGISTiledElevationSource(
            url: .elevation
        )
        // Creates the surface and adds it to the scene.
        let surface = Surface()
        surface.addElevationSource(elevationSource)
        scene.baseSurface = surface
        var point = Point(
            x: 2778453.8008,
            y: 8436451.3882,
            z: 387.4524,
            spatialReference: .webMercator
        )
        let camera = Camera(
            location: point,
            heading: 308.9,
            pitch: 50.7,
            roll: 0.0
        )
        scene.initialViewpoint = Viewpoint(
            boundingGeometry: point,
            camera: camera
        )
        return scene
    }()
    
    @State private var simpleRenderer: SimpleRenderer = {
        let materialFillSymbolLayer = MaterialFillSymbolLayer(color: .yellow)
        materialFillSymbolLayer.colorMixMode = .replace
        materialFillSymbolLayer.edges = SymbolLayerEdges3D(color: .black, width: 0.5)
        // Create the multilayer mesh symbol with the symbol layer
        let meshSymbol = MultilayerMeshSymbol(symbolLayer: materialFillSymbolLayer)
        let simpleRenderer = SimpleRenderer(symbol: meshSymbol)
        return simpleRenderer
    }()
    
    @State private var uniqueValueRenderer: UniqueValueRenderer = {
        UniqueValueRenderer(
            fieldNames: ["usage"],
            uniqueValues: [
                UniqueValue(
                    description: "commercial buildings",
                    label: "commercial buildings",
                    symbol: MultilayerMeshSymbol(
                        symbolLayer: MaterialFillSymbolLayer(
                            color: UIColor(
                                red: 245 / 255,
                                green: 213 / 255,
                                blue: 169 / 255,
                                alpha: 200.0 / 255
                            )
                        )
                    ),
                    values: ["general or commercial"]
                ),
                UniqueValue(
                    description: "residential buildings",
                    label: "residential buildings",
                    symbol: MultilayerMeshSymbol(
                        symbolLayer: MaterialFillSymbolLayer(
                            color: UIColor(red: 210 / 255, green: 254 / 255, blue: 208 / 255, alpha: 1.0)
                        )
                    ),
                    values: ["residential"]
                ),
                UniqueValue(
                    description: "other",
                    label: "other",
                    symbol: MultilayerMeshSymbol(
                        symbolLayer: MaterialFillSymbolLayer(
                            color: UIColor(
                                red: 253 / 255,
                                green: 198 / 255,
                                blue: 227 / 255,
                                alpha: 150.0 / 255
                            )
                        )
                    ),
                    values: ["other"]
                )
            ],
            defaultSymbol: MultilayerMeshSymbol(
                symbolLayer: MaterialFillSymbolLayer(
                    color: UIColor(
                        red: 230 / 255,
                        green: 230 / 255,
                        blue: 230 / 255,
                        alpha: 1.0
                    )
                )
            )
        )
    }()
    
    @State private var classBreaksRenderer: ClassBreaksRenderer = {
        ClassBreaksRenderer(
            fieldName: "yearCompleted",
            classBreaks: [
                ClassBreak(
                    description: "before 1900",
                    label: "before 1900",
                    minValue: 1725.0,
                    maxValue: 1899.0,
                    symbol: {
                        let symbolLayer = MaterialFillSymbolLayer(
                            color: UIColor(
                                red: 230 / 255,
                                green: 238 / 255,
                                blue: 207 / 255,
                                alpha: 1.0
                            )
                        )
                        symbolLayer.colorMixMode = .tint
                        return MultilayerMeshSymbol(symbolLayer: symbolLayer)
                    }()
                ),
                ClassBreak(
                    description: "1900 - 1956",
                    label: "1900 - 1956",
                    minValue: 1900.0,
                    maxValue: 1956.0,
                    symbol: {
                        let symbolLayer = MaterialFillSymbolLayer(
                            color: UIColor(
                                red: 155 / 255,
                                green: 196 / 255,
                                blue: 193 / 255,
                                alpha: 1.0
                            )
                        )
                        symbolLayer.colorMixMode = .tint
                        return MultilayerMeshSymbol(symbolLayer: symbolLayer)
                    }()
                ),
                ClassBreak(
                    description: "1957 - 2000",
                    label: "1957 - 2000",
                    minValue: 1957.0,
                    maxValue: 2000.0,
                    symbol: {
                        let symbolLayer = MaterialFillSymbolLayer(
                            color: UIColor(
                                red: 105 / 255,
                                green: 168 / 255,
                                blue: 183 / 255,
                                alpha: 1.0
                            )
                        )
                        symbolLayer.colorMixMode = .tint
                        return MultilayerMeshSymbol(symbolLayer: symbolLayer)
                    }()
                ),
                ClassBreak(
                    description: "after 2000",
                    label: "after 2000",
                    minValue: 2001.0,
                    maxValue: 3000.0,
                    symbol: {
                        let symbolLayer = MaterialFillSymbolLayer(
                            color: UIColor(
                                red: 75 / 255,
                                green: 126 / 255,
                                blue: 152 / 255,
                                alpha: 1.0
                            )
                        )
                        symbolLayer.colorMixMode = .tint
                        return MultilayerMeshSymbol(symbolLayer: symbolLayer)
                    }()
                )
            ]
        )
    }()
    
    var body: some View {
        SceneView(scene: scene)
            .onAppear {
                // add renderer here
                scene.addOperationalLayer(sceneLayer)
                sceneLayer.renderer = renderer
            }
            .onChange(of: renderer) { newRenderer in
                sceneLayer.renderer = newRenderer
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Picker("Renderer", selection: $rendererSelection) {
                        ForEach(RendererType.allCases, id: \.self) { renderer in
                            Text(renderer.label)
                        }
                    } .onChange(of: rendererSelection) {
                        switch rendererSelection {
                        case .none:
                            renderer = nil
                        case .simpleRenderer:
                            renderer = simpleRenderer
                        case .uniqueValueRenderer:
                            renderer = uniqueValueRenderer
                        case .classBreaksRenderer:
                            renderer = classBreaksRenderer
                        }
                    }
                }
            }
    }
}

enum RendererType: CaseIterable {
    case none
    case simpleRenderer
    case uniqueValueRenderer
    case classBreaksRenderer
    
    var label: String {
        switch self {
        case .none:
            return "None"
        case .simpleRenderer:
            return "Simple Renderer"
        case .uniqueValueRenderer:
            return "Unique Value Renderer"
        case .classBreaksRenderer:
            return "Class Breaks Renderer"
        }
    }
}

extension ApplyRenderersToSceneLayerView { }

private extension URL {
    static var world: URL {
        URL(string: "https://www.arcgis.com/home/item.html?id=fdfa7e3168e74bf5b846fc701180930b")!
    }
    
    static var elevation: URL {
        URL(string: "https://elevation3d.arcgis.com/arcgis/rest/services/WorldElevation3D/Terrain3D/ImageServer")!
    }
}

#Preview {
    ApplyRenderersToSceneLayerView()
}
