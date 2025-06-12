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

struct SetMapImageLayerSublayerVisibilityView: View {
    /// The tracking status for the loading operation.
    @State private var isLoading = false
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    /// Holds the reference to the selected sublayer..
    @State private var sublayerSelection: SublayerSelection = .world
    
    @State private var map: Map = {
        // Makes a new map with an oceans basemap style.
        let map = Map()
        return map
    }()
    
    @State private var imageLayer: ArcGISMapImageLayer = {
        let imageLayer = ArcGISMapImageLayer(url: .arcGISMapImageLayerSample)
        return imageLayer
    }()
    
    @State private var sublayers: [ArcGISMapImageSublayer] = []
    
    init() {
        map.addOperationalLayer(imageLayer)
    }
    
    var body: some View {
        MapViewReader { mapViewProxy in
            MapView(map: map)
                .task {
                    do {
                        try await imageLayer.load()
                        await mapViewProxy.setViewpointCenter(Point(x: -11e6, y: 6e6, spatialReference: .webMercator), scale: 9e7)
                    } catch {
                        self.error = error
                    }
                    for mapLayer in imageLayer.mapImageSublayers {
                        sublayers.append(mapLayer)
                    }
                }
                .toolbar {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Picker("Sublayer", selection: $sublayerSelection) {
                            ForEach(SublayerSelection.allCases, id: \.self) { rule in
                                Text(rule.label)
                            }
                        }
                        .task(id: sublayerSelection) {
                            for (_, sublayer) in sublayers.enumerated() {
                                if sublayer.name == sublayerSelection.label {
                                    sublayer.isVisible = true
                                } else {
                                    sublayer.isVisible = false
                                }
                            }
                        }
                        .pickerStyle(.automatic)
                    }
                }
        }.errorAlert(presentingError: $error)
    }
}

private enum SublayerSelection: CaseIterable, Equatable {
    case cities, continent, world
    
    /// The string to be displayed for each `RuleSelection` option.
    var label: String {
        switch self {
        case .cities: "Cities"
        case .continent: "Continent"
        case .world: "World"
        }
    }
}

extension URL {
    static var arcGISMapImageLayerSample: URL {
        URL(
            string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/SampleWorldCities/MapServer"
        )!
    }
}

#Preview {
    SetMapImageLayerSublayerVisibilityView()
}
