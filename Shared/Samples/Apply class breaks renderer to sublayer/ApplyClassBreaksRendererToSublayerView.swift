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

struct ApplyClassBreaksRendererToSublayerView: View {
    /// The map image layer.
    private let mapImageLayer = ArcGISMapImageLayer(url: URL(string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/Census/MapServer")!)
    
    /// The counties sublayer.
    @State private var countiesLayer: ArcGISMapImageSublayer?
    
    /// The original renderer used to symbolize the sublayer.
    @State private var originalRenderer: Renderer?
    
    /// A Boolean value indicating that the class breaks renderer is applied.
    @State private var applyClassBreaksRenderer = false
    
    /// The map with a topographic basemap style.
    @State private var map: Map = {
        let map = Map(basemapStyle: .arcGISTopographic)
        
        // Sets the initial viewpoint.
        map.initialViewpoint = Viewpoint(
            boundingGeometry: Envelope(
                xMin: -13934661.666904,
                yMin: 331181.323482,
                xMax: -7355704.998713,
                yMax: 9118038.075882,
                spatialReference: .webMercator
            )
        )
        return map
    }()

    /// The error shown in the error alert.
    @State private var error: Error?

    var body: some View {
        MapView(map: map)
            .task {
                // Adds the map image layer to the map.
                map.addOperationalLayer(mapImageLayer)
                await loadMapImageSublayer()
            }
            .overlay(alignment: .topTrailing) {
                VStack(alignment: .leading) {
                    Text("""
                        Click the 'Change Sublayer Renderer'
                        button to apply a class breaks
                        renderer to the counties sublayer.
                    """)
                }
                .fixedSize()
                .padding()
                .background(.thinMaterial)
                .clipShape(.rect(cornerRadius: 10))
                .shadow(radius: 50)
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button(applyClassBreaksRenderer ? "Reset" : "Change Sublayer Renderer") {
                        if applyClassBreaksRenderer {
                            // Applies the original renderer.
                            countiesLayer?.renderer = originalRenderer
                        } else {
                            // Applies the class breaks renderer.
                            countiesLayer?.renderer = .populationRenderer
                        }
                        applyClassBreaksRenderer.toggle()
                    }
                }
            }
            .errorAlert(presentingError: $error)
    }
    
    func loadMapImageSublayer() async {
        do {
            // Loads the map image layer.
            try await mapImageLayer.load()
            // Gets the sublayers.
            let mapImageSublayers = mapImageLayer.mapImageSublayers
            guard mapImageSublayers.count >= 3 else { return }
            
            // Gets the third sublayer.
            let sublayer = mapImageSublayers[2]
            // Loads the sublayer.
            try await sublayer.load()
            // Stores the counties layer and original renderer.
            countiesLayer = sublayer
            originalRenderer = sublayer.renderer
        } catch {
            self.error = error
        }
    }
}

private extension Renderer {
    /// Creates a class breaks renderer for counties in the US based on their
    /// population in 2007.
    ///
    /// - Returns: A `ClassBreaksRenderer` object.
    static let populationRenderer: ClassBreaksRenderer = {
        // Outline symbol.
        let lineSymbol = SimpleLineSymbol(style: .solid, color: UIColor(white: 0.6, alpha: 1), width: 0.5)
        
        // Symbol for each class break.
        let symbol1 = SimpleFillSymbol(style: .solid, color: UIColor(red: 0.89, green: 0.92, blue: 0.81, alpha: 1), outline: lineSymbol)
        let symbol2 = SimpleFillSymbol(style: .solid, color: UIColor(red: 0.59, green: 0.76, blue: 0.75, alpha: 1), outline: lineSymbol)
        let symbol3 = SimpleFillSymbol(style: .solid, color: UIColor(red: 0.38, green: 0.65, blue: 0.71, alpha: 1), outline: lineSymbol)
        let symbol4 = SimpleFillSymbol(style: .solid, color: UIColor(red: 0.27, green: 0.49, blue: 0.59, alpha: 1), outline: lineSymbol)
        let symbol5 = SimpleFillSymbol(style: .solid, color: UIColor(red: 0.16, green: 0.33, blue: 0.47, alpha: 1), outline: lineSymbol)
        
        // Class breaks.
        let classBreak1 = ClassBreak(description: "-99 to 8,560", label: "-99 to 8,560", minValue: -99, maxValue: 8_560, symbol: symbol1)
        let classBreak2 = ClassBreak(description: "> 8,560 to 18,109", label: "> 8,560 to 18,109", minValue: 8_561, maxValue: 18_109, symbol: symbol2)
        let classBreak3 = ClassBreak(description: "> 18,109 to 35,501", label: "> 18,109 to 35,501", minValue: 18_110, maxValue: 35_501, symbol: symbol3)
        let classBreak4 = ClassBreak(description: "> 35,501 to 86,100", label: "> 35,501 to 86,100", minValue: 35_502, maxValue: 86_100, symbol: symbol4)
        let classBreak5 = ClassBreak(description: "> 86,100 to 10,110,975", label: "> 86,100 to 10,110,975", minValue: 86_101, maxValue: 10_110_975, symbol: symbol2)
        
        return ClassBreaksRenderer(fieldName: "POP2007", classBreaks: [classBreak1, classBreak2, classBreak3, classBreak4, classBreak5])
    }()
}

#Preview {
    ApplyClassBreaksRendererToSublayerView()
}
