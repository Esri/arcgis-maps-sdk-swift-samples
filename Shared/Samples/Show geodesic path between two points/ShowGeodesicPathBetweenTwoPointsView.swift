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

struct ShowGeodesicPathBetweenTwoPointsView: View {
    @State private var map = Map(basemapStyle: .arcGISImageryStandard)
    @State private var overlay = {
        let overlay = GraphicsOverlay()
        return overlay
    }()
    
    enum TapState {
        case noGraphics
        case startOnly(Graphic)
        case both(Graphic, Graphic)
    }
    
    @State private var tapState: TapState = .noGraphics {
        didSet {
            updateOverlay()
            updateLength()
        }
    }
    
    private var graphic1: Graphic? {
//        overlay.graphics.first
        switch tapState {
        case .noGraphics:
            nil
        case .startOnly(let graphic):
            graphic
        case .both(let graphic, let graphic2):
            graphic
        }
    }
    
    private var graphic2: Graphic? {
//        overlay.graphics.count > 1 ? overlay.graphics[1] : nil
        switch tapState {
        case .noGraphics, .startOnly:
            nil
        case .both(let graphic, let graphic2):
            graphic2
        }
    }
    
    var body: some View {
        MapView(map: map, graphicsOverlays: [overlay])
            .onSingleTapGesture { _, mapPoint in
                switch tapState {
                case .noGraphics:
                    tapState = .startOnly(Self.makeGraphic(at: mapPoint))
                case .startOnly(let graphic):
                    tapState = .both(graphic, Self.makeGraphic(at: mapPoint))
                case .both(let graphic, let graphic2):
                    tapState = .noGraphics
                }
            }
    }
    
    private static func makeGraphic(at point: Point) -> Graphic {
        let symbol = SimpleMarkerSymbol(style: .cross, color: .blue, size: 20)
        return Graphic(geometry: point, symbol: symbol)
    }
    
    private func updateOverlay() {
        overlay.removeAllGraphics()
        
        switch tapState {
        case .noGraphics:
            break
        case .startOnly(let graphic):
            overlay.addGraphic(graphic)
        case .both(let graphic, let graphic2):
            overlay.addGraphic(graphic)
            overlay.addGraphic(graphic2)
        }
    }
    
    private func updateLength() {
        switch tapState {
        case .noGraphics:
            break
        case .startOnly(let graphic):
            break
        case .both(let graphic, let graphic2):
            break
        }
    }
}

#Preview {
    ShowGeodesicPathBetweenTwoPointsView()
}
