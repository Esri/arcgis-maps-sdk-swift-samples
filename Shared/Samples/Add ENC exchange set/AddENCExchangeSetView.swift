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
    /// The tracking status for the loading operation.
    @State private var isLoading = false
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    /// The data model for the sample.
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
                        ProgressView("Loading…")
                            .padding()
                            .background(.ultraThickMaterial)
                            .cornerRadius(10)
                            .shadow(radius: 50)
                    }
                }
                .task {
                    do {
                        isLoading = true
                        try await model.addENCExchangeSet()
                        if let extent = model.completeExtent {
                            await mapProxy.setViewpoint(
                                Viewpoint(center: extent.center, scale: 67000)
                            )
                        }
                    } catch {
                        self.error = error
                    }
                }
        }
        .errorAlert(presentingError: $error)
    }
}

private extension AddENCExchangeSetView {
    class Model: ObservableObject {
        /// A map with Oceans style.
        let map: Map = {
            let map = Map(basemapStyle: .arcGISOceans)
            map.initialViewpoint = Viewpoint(
                latitude: -32.5,
                longitude: 60.95,
                scale: 67000
            )
            return map
        }()
        
        /// The geometry that represents a rectangular shape that encompasses the area on the
        /// map where the ENC data will be rendering.
        private(set) var completeExtent: Envelope?
        
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
        
        deinit {
            // Recursively remove all files in the sample-specific
            // temporary folder and the folder itself.
            try? FileManager.default.removeItem(at: temporaryURL)
            // Reset ENC environment display settings.
            let displaySettings = ENCEnvironmentSettings.shared.displaySettings
            displaySettings.textGroupVisibilitySettings.resetToDefaults()
            displaySettings.viewingGroupSettings.resetToDefaults()
        }
        
        /// Gets the ENC exchange set data and loads it and sets the display settings.
        /// - Parameter mapProxy: MapView proxy for centering the map on the ENC envelope.
        func addENCExchangeSet() async throws {
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
            try await renderENCData(dataset: exchangeSet.datasets)
        }
        
        /// Maps the exchange set data to ENC layer and ENC cells and loads the layers.
        /// - Parameter dataset: The ENC dataset previously loaded.
        private func renderENCData(dataset: [ENCDataset]) async throws {
            let encLayers = dataset.map {
                ENCLayer(
                    cell: ENCCell(
                        dataset: $0
                    )
                )
            }
            map.addOperationalLayers(encLayers)
            await encLayers.load()
            let extents = map.operationalLayers.compactMap(\.fullExtent)
            completeExtent = GeometryEngine.combineExtents(of: extents)
        }
        
        /// Updates the display settings to make the chart less cluttered.
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
        subdirectory: "hydrography"
    )!
}

#Preview {
    AddENCExchangeSetView()
}
