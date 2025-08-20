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
    /// Renderer type selected by the user.
    @State private var rendererSelection: RendererType = .none
    
    /// Scene layer for Helsinki scene.
    private var sceneLayer: ArcGISSceneLayer {
        scene.operationalLayers.first as! ArcGISSceneLayer
    }
    
    /// Scene with elevation layer and viewpoint centered on Helsinki.
    @State private var scene: ArcGIS.Scene = {
        let scene = Scene(basemapStyle: .arcGISLightGray)
        // Creates the surface and adds it to the scene.
        let surface = Surface()
        surface.addElevationSource(
            ArcGISTiledElevationSource(
                url: .worldElevationService
            )
        )
        scene.baseSurface = surface
        scene.initialViewpoint = Viewpoint(
            boundingGeometry: .helsinkiCenter,
            camera: Camera(
                location: .helsinkiCenter,
                heading: 308.9,
                pitch: 50.7,
                roll: 0.0
            )
        )
        scene.addOperationalLayer(ArcGISSceneLayer(url: .helsinkiScene))
        return scene
    }()
    
    /// Simple renderer that adds yellow mesh to buildings.
    @State private var simpleRenderer: SimpleRenderer = {
        let materialFillSymbolLayer = MaterialFillSymbolLayer(
            color: .yellow
        )
        materialFillSymbolLayer.colorMixMode = .replace
        materialFillSymbolLayer.edges = SymbolLayerEdges3D(
            color: .black,
            width: 0.5
        )
        let meshSymbol = MultilayerMeshSymbol(
            symbolLayer: materialFillSymbolLayer
        )
        return SimpleRenderer(symbol: meshSymbol)
    }()
    
    /// Renderer that provides color depending on building usage (i.e. commercial, residential).
    @State private var uniqueValueRenderer: UniqueValueRenderer = {
        UniqueValueRenderer(
            fieldNames: ["usage"],
            uniqueValues: [
                .commercial,
                .residential,
                .otherUsage
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
    
    /// A class breaks renderer that categorizes data based on 'yearCompleted' values.
    @State private var classBreaksRenderer: ClassBreaksRenderer = {
        ClassBreaksRenderer(
            fieldName: "yearCompleted",
            classBreaks: [
                .before1900,
                .from1900to1956,
                .from1957to2000,
                .after2000
            ]
        )
    }()
    
    var body: some View {
        SceneView(scene: scene)
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Picker("Renderer selected", selection: $rendererSelection) {
                        ForEach(RendererType.allCases, id: \.self) { renderer in
                            Text(renderer.label)
                        }
                    }
                    .onChange(of: rendererSelection) {
                        // Update the renderer based on selection.
                        switch rendererSelection {
                        case .none:
                            sceneLayer.renderer = nil
                        case .simpleRenderer:
                            sceneLayer.renderer = simpleRenderer
                        case .uniqueValueRenderer:
                            sceneLayer.renderer = uniqueValueRenderer
                        case .classBreaksRenderer:
                            sceneLayer.renderer = classBreaksRenderer
                        }
                    }
                }
            }
    }
}

// Enum to manage available renderer options in the Picker.
private enum RendererType: CaseIterable {
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

// Defines custom color and symbol for different ranges of 'yearCompleted'.
private extension ClassBreak {
    static var before1900: ClassBreak {
        ClassBreak(
            description: "before 1900",
            label: "before 1900",
            minValue: 1725,
            maxValue: 1900,
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
        )
    }
    
    static var from1900to1956: ClassBreak {
        ClassBreak(
            description: "1900 - 1956",
            label: "1900 - 1956",
            minValue: 1900,
            maxValue: 1957,
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
        )
    }
    
    static var from1957to2000: ClassBreak {
        ClassBreak(
            description: "1957 - 2000",
            label: "1957 - 2000",
            minValue: 1957,
            maxValue: 2000,
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
        )
    }
    
    static var after2000: ClassBreak {
        ClassBreak(
            description: "after 2000",
            label: "after 2000",
            minValue: 2000,
            maxValue: 3000,
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
    }
}

// Defines unique value symbols for building usage types.
private extension UniqueValue {
    static var commercial: UniqueValue {
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
        )
    }
    
    static var residential: UniqueValue {
        UniqueValue(
            description: "residential buildings",
            label: "residential buildings",
            symbol: MultilayerMeshSymbol(
                symbolLayer: MaterialFillSymbolLayer(
                    color: UIColor(
                        red: 210 / 255,
                        green: 254 / 255,
                        blue: 208 / 255,
                        alpha: 1.0
                    )
                )
            ),
            values: ["residential"]
        )
    }
    
    static var otherUsage: UniqueValue {
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
    }
}

private extension Geometry {
    /// Predefined geometry point for Helsinki city center.
    static var helsinkiCenter: Point {
        Point(
            x: 2778453.8008,
            y: 8436451.3882,
            z: 387.4524,
            spatialReference: .webMercator
        )
    }
}

/// Scene and elevation data sources
private extension URL {
    static var helsinkiScene: URL {
        URL(string: "https://www.arcgis.com/home/item.html?id=fdfa7e3168e74bf5b846fc701180930b")!
    }
    
    static var worldElevationService: URL {
        URL(string: "https://elevation3d.arcgis.com/arcgis/rest/services/WorldElevation3D/Terrain3D/ImageServer")!
    }
}

#Preview {
    ApplyRenderersToSceneLayerView()
}
