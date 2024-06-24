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

struct AddENCExchangeSetView: View {
    // The tracking status for the loading operation.
    @State private var isLoading = false
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    @StateObject private var model = Model()
    
    var body: some View {
        MapViewReader { mapProxy in
            MapView(map: model.map)
                .onDrawStatusChanged { drawStatus in
                    // Updates the state when the map's draw status changes.
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
                            .cornerRadius(10)
                            .shadow(radius: 50)
                    }
                }
                .task {
                    do {
                        isLoading = true
                        try await model.addENCExchangeSet(mapProxy: mapProxy)
                    } catch {
                        self.error = error
                    }
                }
        }
        .errorAlert(presentingError: $error)
    }
}

private extension AddENCExchangeSetView {
    @MainActor
    class Model: ObservableObject {
        /// A map with viewpoint set to Amberg, Germany.
        let map: Map = {
            let map = Map(basemapStyle: .arcGISOceans)
            map.initialViewpoint = Viewpoint(
                latitude: -32.5,
                longitude: 60.95,
                scale: 67000
            )
            return map
        }()
        
        private var completeExtent: Envelope?
        
        /// A URL to the temporary SENC data directory.
        private let temporaryURL: URL = {
            let directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(
                ProcessInfo().globallyUniqueString
            )
            // Create and return the full, unique URL to the temporary folder.
            try? FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
            return directoryURL
        }()
        
        /// Gets the ENC exchange set data and loads it and sets the display settings.
        /// - Parameter mapProxy: MapView proxy
        func addENCExchangeSet(mapProxy: MapViewProxy) async throws {
            let exchangeSet = ENCExchangeSet(fileURLs: [.exchangeSet])
            // URL to the "hydrography" data folder that contains the "S57DataDictionary.xml" file.
            let resourceURL = URL.hydrographyDirectory.deletingLastPathComponent()
            // Set environment settings for loading the dataset.
            let environmentSettings = ENCEnvironmentSettings.shared
            environmentSettings.resourceURL = resourceURL
            // The SENC data directory is for temporarily storing generated files.
            environmentSettings.sencDataURL = temporaryURL
            updateDisplaySettings()
            try await exchangeSet.load()
            if exchangeSet.loadStatus == .loaded {
                try await renderENCData(dataSet: exchangeSet.datasets)
                if let extent = completeExtent {
                    await mapProxy.setViewpoint(
                        Viewpoint(center: extent.center, scale: 67000)
                    )
                }
            }
        }
        
        
        /// Maps the exchange set data to ENC layer and ENC cells and loads the layers.
        /// - Parameter dataSet: ENC dataset
        private func renderENCData(dataSet: [ENCDataset]) async throws {
            let encLayers = dataSet.map {
                ENCLayer(
                    cell: ENCCell(
                        dataset: $0
                    )
                )
            }
            for encLayer in encLayers {
                map.addOperationalLayer(encLayer)
                try await encLayer.load()
                if encLayer.loadStatus == .loaded,
                   let envelope = encLayer.fullExtent {
                    if completeExtent == nil {
                        completeExtent = envelope
                    } else {
                        completeExtent = GeometryEngine.combineExtents(
                            completeExtent!,
                            envelope
                        )
                    }
                }
            }
        }
        
        /// Update the display settings to make the chart less cluttered.
        private func updateDisplaySettings() {
            let displaySettings = ENCEnvironmentSettings.shared.displaySettings
            let textGroupVisibilitySettings = displaySettings.textGroupVisibilitySettings
            textGroupVisibilitySettings.includesGeographicNames = false
            textGroupVisibilitySettings.includesNatureOfSeabed = false
            let viewingGroupSettings = displaySettings.viewingGroupSettings
            viewingGroupSettings.includesBuoysBeaconsAidsToNavigation = false
            viewingGroupSettings.includesDepthContours = false
            viewingGroupSettings.includesSpotSoundings = false
        }
    }
}

private extension URL {
    static let exchangeSet = Bundle.main.url(
        forResource: "CATALOG",
        withExtension: "031",
        subdirectory: "ExchangeSetwithoutUpdates/ExchangeSetwithoutUpdates/ENC_ROOT"
    )!
    
    static let hydrographyDirectory = Bundle.main.url(
        forResource: "S57DataDictionary",
        withExtension: "xml",
        subdirectory: "ExchangeSetwithoutUpdates/ExchangeSetwithoutUpdates/ENC_ROOT/hydrography"
    )!
}

#Preview {
    AddENCExchangeSetView()
}
