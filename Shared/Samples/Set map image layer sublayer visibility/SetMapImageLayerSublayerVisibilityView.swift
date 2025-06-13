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
    
    @State private var map: Map = {
        let map = Map()
        return map
    }()
    
    @State private var mapImageLayer: ArcGISMapImageLayer = {
        let imageLayer = ArcGISMapImageLayer(url: .arcGISMapImageLayerSample)
        return imageLayer
    }()
    
    @State private var sublayerOptions: [SublayerOption] = []
    
    var body: some View {
        MapView(map: map)
            .onDrawStatusChanged { drawStatus in
                // Updates the the loading state when the map's draw status is completed.
                withAnimation {
                    if drawStatus == .completed {
                        isLoading = false
                    }
                }
            }
            .overlay(alignment: .center) {
                if isLoading {
                    ProgressView("Loading...")
                        .padding()
                        .background(.ultraThickMaterial)
                        .clipShape(.rect(cornerRadius: 10))
                        .shadow(radius: 50)
                }
            }
            .task {
                // Adds the map image layer to the map.
                map.addOperationalLayer(mapImageLayer)
                do {
                    // Loads the map image layer.
                    try await mapImageLayer.load()
                    sublayerOptions = mapImageLayer.mapImageSublayers.enumerated().map { index, mapImageSublayer in
                        SublayerOption(
                            name: mapImageSublayer.name,
                            id: index,
                            isEnabled: mapImageSublayer.isVisible,
                            sublayer: mapImageSublayer
                        )
                    }
                } catch {
                    self.error = error
                }
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Menu {
                        ForEach($sublayerOptions, id: \.id) { $sublayerOption in
                            Toggle(isOn: $sublayerOption.isEnabled) {
                                Text(sublayerOption.name)
                            }
                            .onChange(of: sublayerOption.isEnabled) {
                                sublayerOption.sublayer.isVisible = sublayerOption.isEnabled
                            }
                        }
                    } label: {
                        Text("Sublayers")
                    }
                }
            }
            .errorAlert(presentingError: $error)
    }
}

private struct SublayerOption: Equatable, Identifiable {
    var name: String
    let id: Int
    var isEnabled = true
    let sublayer: ArcGISMapImageSublayer
}

extension SublayerOption: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
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
