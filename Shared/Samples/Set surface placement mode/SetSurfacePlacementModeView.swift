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

import SwiftUI
import ArcGIS

struct SetSurfacePlacementModeView: View {
    /// The view model for this sample.
    @StateObject private var model = Model()
    
    var body: some View {
        VStack(spacing: 0) {
            SceneView(scene: model.scene, graphicsOverlays: model.graphicsOverlays)
            VStack {
                HStack {
                    Text("Draped mode:")
                        .frame(width: 120, alignment: .leading)
                    
                    Picker("Draped Mode", selection: $model.drapedMode) {
                        ForEach(DrapedMode.allCases, id: \.self) { mode in
                            Text(mode.label)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .frame(maxWidth: 540)
                
                HStack {
                    Text("Z-value: \(model.zValue, format: .measurement(width: .narrow))")
                        .frame(width: 120, alignment: .leading)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    
                    Slider(value: $model.zValue.value, in: model.zValueRange.doubleRange) {
                        Text("Z-value")
                    } minimumValueLabel: {
                        Text(model.zValueRange.lowerBound, format: .measurement(width: .narrow))
                    } maximumValueLabel: {
                        Text(model.zValueRange.upperBound, format: .measurement(width: .narrow))
                    }
                }
                .frame(maxWidth: 540)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial, ignoresSafeAreaEdges: .all)
        }
    }
}

private extension SetSurfacePlacementModeView {
    /// The model used to store the geo model and other expensive objects
    /// used in this view.
    class Model: ObservableObject {
        /// The range of possible z-values. The z-value range is 0 to 140 meters in this sample.
        let zValueRange = Measurement.zMin...Measurement.zMax
        
        /// The current z-value.
        @Published var zValue: Measurement<UnitLength> {
            didSet {
                updateGraphics()
            }
        }
        
        /// The current draped mode.
        @Published var drapedMode: DrapedMode {
            didSet {
                updateDrapedGraphics()
            }
        }
        
        /// The scene for this sample.
        let scene: ArcGIS.Scene
        
        /// The graphics overlays containing each placement graphic.
        let graphicsOverlays: [GraphicsOverlay]
        
        /// A dictionary for graphics overlays of different surface placement modes.
        private let overlaysBySurfacePlacement: [SurfacePlacement: GraphicsOverlay]
        
        init() {
            // Creates the scene with an initial viewpoint.
            let scene = Scene(basemapStyle: .arcGISImagery)
            let point = Point(x: -4.4595, y: 48.3889, z: 80, spatialReference: .wgs84)
            let camera = Camera(location: point, heading: 330, pitch: 97, roll: 0)
            scene.initialViewpoint = Viewpoint(boundingGeometry: point, camera: camera)
            
            // Creates and adds an elevation source to a surface and sets it
            // to the scene's base surface.
            let surface = Surface()
            surface.addElevationSource(ArcGISTiledElevationSource(url: .worldElevationService))
            scene.baseSurface = surface
            
            // Adds a scene layer from a URL to the scene's operational layers.
            scene.addOperationalLayer(ArcGISSceneLayer(url: .sceneService))
            self.scene = scene
            
            // Creates the graphics overlays for each surface placement.
            graphicsOverlays = SurfacePlacement.allCases.map(Self.makeGraphicsOverlay)
            
            // Creates the dictionary for graphics overlays of different surface placements.
            overlaysBySurfacePlacement = Dictionary(uniqueKeysWithValues: zip(SurfacePlacement.allCases, graphicsOverlays))
            
            // Sets the initial z-value to the mid-range of the possible z-values.
            zValue = Measurement(value: Measurement.zMid, unit: UnitLength.meters)
            
            // Sets the current draped mode to billboarded.
            drapedMode = .billboarded
            
            // Updates the draped graphics to show the current draped mode.
            updateDrapedGraphics()
        }
        
        /// Updates the draped graphics to change their visibility based on the current draped mode.
        private func updateDrapedGraphics() {
            overlaysBySurfacePlacement[.drapedBillboarded]?.isVisible = drapedMode == .billboarded
            overlaysBySurfacePlacement[.drapedFlat]?.isVisible = drapedMode == .flat
        }
        
        /// Updates the graphics' z-value.
        private func updateGraphics() {
            overlaysBySurfacePlacement.values.forEach { graphicsOverlay in
                graphicsOverlay.graphics.forEach { graphic in
                    graphic.geometry = GeometryEngine.makeGeometry(from: graphic.geometry!, z: zValue.value)
                }
            }
        }
        
        /// Creates a graphics overlay for the given surface placement.
        /// - Parameter surfacePlacement: The surface placement for which to create a graphics overlay.
        /// - Returns: A new `GraphicsOverlay` object.
        private static func makeGraphicsOverlay(for surfacePlacement: SurfacePlacement) -> GraphicsOverlay {
            // Creates symbols for the graphic.
            let markerSymbol = SimpleMarkerSymbol(style: .triangle, color: .red, size: 20)
            let textSymbol = TextSymbol(text: surfacePlacement.label, color: .blue, size: 20, horizontalAlignment: .left)
            textSymbol.haloColor = .cyan
            textSymbol.haloWidth = 2
            
            // Adds an offset to avoid overlapping the text and marker symbols.
            textSymbol.offsetY = 20
            
            // Adds an offset to x and y of the geometry to better differentiate certain geometries.
            let offset = surfacePlacement == .relativeToScene ? 2e-4 : 0
            
            // Creates the graphics for the graphics overlay.
            let surfaceRelatedPoint = Point(x: -4.4609257 + offset, y: 48.3903965 + offset, z: Measurement.zMid, spatialReference: .wgs84)
            let graphics = [markerSymbol, textSymbol].map { Graphic(geometry: surfaceRelatedPoint, symbol: $0) }
            
            // Creates the graphics overlay and sets its scene properties'
            // surface placement to the respective surface placement.
            let overlay = GraphicsOverlay(graphics: graphics)
            overlay.sceneProperties.surfacePlacement = surfacePlacement
            return overlay
        }
    }
    
    enum DrapedMode: CaseIterable {
        case billboarded
        case flat
        
        /// A human-readable label for the draped mode.
        var label: String {
            switch self {
            case .billboarded: return "Billboarded"
            case .flat: return "Flat"
            }
        }
    }
}

private extension SurfacePlacement {
    static var allCases: [Self] { [.absolute, .drapedBillboarded, .drapedFlat, .relative, .relativeToScene] }
    
    /// A human-readable label of the surface placement.
    var label: String {
        switch self {
        case .absolute: return "Absolute"
        case .drapedBillboarded: return "Draped Billboarded"
        case .drapedFlat: return "Draped Flat"
        case .relative: return "Relative"
        case .relativeToScene: return "Relative to Scene"
        @unknown default: return "Unknown"
        }
    }
}

private extension Measurement where UnitType == UnitLength {
    /// The minimum z-value.
    static var zMin: Self { Measurement(value: 0, unit: UnitLength.meters) }
    
    /// The maximum z-value.
    static var zMax: Self { Measurement(value: 140, unit: UnitLength.meters) }
    
    /// The mid-range of the possible z-values.
    static var zMid: Double { (zMin.value + zMax.value) / 2 }
}

private extension ClosedRange where Bound == Measurement<UnitLength> {
    /// The measurement's values as a closed range of doubles.
    var doubleRange: ClosedRange<Double> { self.lowerBound.value...self.upperBound.value }
}

private extension URL {
    /// The URL of a Brest, France buildings scene service.
    static var sceneService: URL {
        URL(string: "https://tiles.arcgis.com/tiles/P3ePLMYs2RVChkJx/arcgis/rest/services/Buildings_Brest/SceneServer")!
    }
    
    /// The URL of the Terrain 3D ArcGIS REST Service.
    static var worldElevationService: URL {
        URL(string: "https://elevation3d.arcgis.com/arcgis/rest/services/WorldElevation3D/Terrain3D/ImageServer")!
    }
}

#Preview {
    SetSurfacePlacementModeView()
}
