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

struct StylePointWithDistanceCompositeSceneSymbolView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// The distance from the target object to the camera in meters.
    @State private var cameraDistance = Measurement(value: 0, unit: UnitLength.meters)
    
    var body: some View {
        SceneView(
            scene: model.scene,
            cameraController: model.cameraController,
            graphicsOverlays: [model.graphicsOverlay]
        )
        .overlay(alignment: .top) {
            VStack {
                Text("Zoom in and out to see the symbol change.")
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(.thinMaterial, ignoresSafeAreaEdges: .horizontal)
                
                HStack {
                    Spacer()
                    HStack {
                        Text("Distance:")
                        Text(cameraDistance, format: .measurement(
                            width: .narrow,
                            usage: .asProvided,
                            numberFormatStyle: .number.precision(.fractionLength(0))
                        ))
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
                    .shadow(radius: 3)
                }
                .padding(.trailing, 8)
            }
        }
        .task {
            for await newDistance in model.cameraController.$cameraDistance {
                cameraDistance.value = newDistance
            }
        }
    }
}

private extension StylePointWithDistanceCompositeSceneSymbolView {
    /// The view model for the sample.
    class Model: ObservableObject {
        /// A scene with an imagery basemap and world elevation surface.
        let scene: ArcGIS.Scene = {
            let scene = Scene(basemapStyle: .arcGISImagery)
            let elevationSource = ArcGISTiledElevationSource(url: .worldElevationService)
            scene.baseSurface.addElevationSource(elevationSource)
            return scene
        }()
        
        /// The camera controller focused on the plane graphic.
        private(set) var cameraController: OrbitGeoElementCameraController!
        
        /// The graphics overlay for the plane graphic.
        let graphicsOverlay: GraphicsOverlay = {
            let graphicsOverlay = GraphicsOverlay()
            graphicsOverlay.sceneProperties.surfacePlacement = .relative
            return graphicsOverlay
        }()
        
        /// The plane graphic created from a distance composite symbol.
        private let planeGraphic: Graphic = {
            // Create the different symbols.
            let planeSymbol = ModelSceneSymbol(url: .bristol, scale: 100)
            let coneSymbol = SimpleMarkerSceneSymbol.cone(
                color: .red,
                diameter: 200,
                height: 600,
                anchorPosition: .center
            )
            coneSymbol.pitch = -90.0
            let circleSymbol = SimpleMarkerSymbol(style: .circle, color: .red, size: 10)
            
            // Create a distance composite symbol using the symbols.
            let distanceCompositeSymbol = DistanceCompositeSceneSymbol()
            distanceCompositeSymbol.addRange(
                DistanceSymbolRange(symbol: planeSymbol, maxDistance: 10000)
            )
            distanceCompositeSymbol.addRange(
                DistanceSymbolRange(symbol: coneSymbol, minDistance: 10001, maxDistance: 30000)
            )
            distanceCompositeSymbol.addRange(
                DistanceSymbolRange(symbol: circleSymbol, minDistance: 30001)
            )
            
            // Create a graphic using the distance composite symbol.
            let planePosition = Point(x: -2.708, y: 56.096, z: 5000, spatialReference: .wgs84)
            let planeGraphic = Graphic(geometry: planePosition, symbol: distanceCompositeSymbol)
            
            return planeGraphic
        }()
        
        init() {
            graphicsOverlay.addGraphic(planeGraphic)
            
            // Create the camera controller targeted on the plane graphic.
            cameraController = {
                let cameraController = OrbitGeoElementCameraController(
                    target: planeGraphic,
                    distance: 4000
                )
                cameraController.cameraPitchOffset = 80
                cameraController.cameraHeadingOffset = -30
                return cameraController
            }()
        }
    }
}

private extension URL {
    /// A URL to the local Bristol 3D model file.
    static var bristol: URL {
        Bundle.main.url(forResource: "Bristol", withExtension: "dae", subdirectory: "Bristol")!
    }
    
    /// A world elevation service from the Terrain3D ArcGIS REST service.
    static var worldElevationService: URL {
        URL(string: "https://elevation3d.arcgis.com/arcgis/rest/services/WorldElevation3D/Terrain3D/ImageServer")!
    }
}
