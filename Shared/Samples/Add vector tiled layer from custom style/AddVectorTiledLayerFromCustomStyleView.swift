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

struct AddVectorTiledLayerFromCustomStyleView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// The viewpoint used to update the map view.
    @State private var viewpoint: Viewpoint?
    
    /// The label of the style selected by the picker.
    @State private var selectedStyleLabel = "Default"
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    var body: some View {
        MapView(map: model.map, viewpoint: viewpoint)
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Picker("Style", selection: $selectedStyleLabel) {
                        Section("Online Styles") {
                            ForEach(model.onlineStyles, id: \.key) { label, _ in
                                Text(label)
                            }
                        }
                        Section("Offline Styles") {
                            ForEach(model.offlineStyles, id: \.key) { label, _ in
                                Text(label)
                            }
                        }
                    }
                    .task(id: selectedStyleLabel) {
                        // Updates the map's layer when the picker selection changes.
                        do {
                            viewpoint = try await model.setVectorTiledLayer(
                                label: selectedStyleLabel
                            )
                        } catch {
                            self.error = error
                        }
                    }
                    .errorAlert(presentingError: $error)
                }
            }
    }
}

// MARK: Model

private extension AddVectorTiledLayerFromCustomStyleView {
    /// The view model for the sample.
    @MainActor
    final class Model: ObservableObject {
        /// A map with no specified style.
        let map = Map()
        
        /// The labels and portal item IDs of the online styles.
        let onlineStyles: KeyValuePairs = [
            "Default": "1349bfa0ed08485d8a92c442a3850b06",
            "Style 1": "bd8ac41667014d98b933e97713ba8377",
            "Style 2": "02f85ec376084c508b9c8e5a311724fa",
            "Style 3": "1bf0cc4a4380468fbbff107e100f65a5"
        ]
        
        /// The labels and portal item IDs of the offline styles.
        let offlineStyles: KeyValuePairs = [
            "Light": "e01262ef2a4f4d91897d9bbd3a9b1075",
            "Dark": "ce8a34e5d4ca4fa193a097511daa8855"
        ]
        
        /// The cached vector tiled layers keyed by the label of their associated style.
        private var vectorTiledLayers: [String: ArcGISVectorTiledLayer] = [:]
        
        /// The URL to the temporary directory for the offline style files.
        private let temporaryDirectoryURL = FileManager.createTemporaryDirectory()
        
        /// The vector tile cache for creating the offline vector tiled layers.
        private let vectorTileCache = VectorTileCache(name: "dodge_city", bundle: .main)!
        
        deinit {
            // Removes all of the temporary offline style files used by sample.
            try? FileManager.default.removeItem(at: temporaryDirectoryURL)
        }
        
        /// Sets the vector tiled layer for a given style on the map.
        /// - Parameter label: The label of the style associated with the layer.
        /// - Returns: A viewpoint framing some of the layer's data.
        func setVectorTiledLayer(label: String) async throws -> Viewpoint {
            // Gets or creates a vector tile layer and adds it to the map as a basemap.
            let vectorTiledLayer = if let cachedVectorTiledLayer = vectorTiledLayers[label] {
                cachedVectorTiledLayer
            } else {
                try await cacheVectorTiledLayer(label: label)
            }
            map.basemap = Basemap(baseLayer: vectorTiledLayer)
            
            if vectorTiledLayer.vectorTileCache != nil {
                // Uses a Dodge City, KS viewpoint if the layer was created using the tile cache.
                return Viewpoint(latitude: 37.76528, longitude: -100.01766, scale: 4e4)
            } else {
                // Uses a Europe/Africa viewpoint if the layer was created using an online style.
                return Viewpoint(latitude: 28.53345, longitude: 17.56488, scale: 1e8)
            }
        }
        
        /// Creates and caches a vector tiled layer for a given style.
        /// - Parameter label: The label of the style associated with the layer.
        /// - Returns: The cached `ArcGISVectorTiledLayer`.
        private func cacheVectorTiledLayer(label: String) async throws -> ArcGISVectorTiledLayer {
            let vectorTiledLayer: ArcGISVectorTiledLayer
            if let onlineStyle = onlineStyles.first(where: { $0.key == label }) {
                vectorTiledLayer = makeOnlineVectorTiledLayer(itemID: onlineStyle.value)
            } else {
                let offlineStyle = offlineStyles.first(where: { $0.key == label })!
                vectorTiledLayer = try await makeOfflineVectorTiledLayer(itemID: offlineStyle.value)
            }
            
            try await vectorTiledLayer.load()
            vectorTiledLayers[label] = vectorTiledLayer
            
            return vectorTiledLayer
        }
        
        /// Creates a vector tiled layer using a portal item.
        /// - Parameter itemID: The ID of the portal item.
        /// - Returns: A new `ArcGISVectorTiledLayer` object.
        private func makeOnlineVectorTiledLayer(itemID: String) -> ArcGISVectorTiledLayer {
            let portalItem = PortalItem(
                portal: .arcGISOnline(connection: .anonymous),
                id: .init(itemID)!
            )
            return ArcGISVectorTiledLayer(item: portalItem)
        }
        
        /// Creates a vector tiled layer using a local vector tile cache and an item resource cache.
        /// - Parameter itemID: The ID of the portal item used to create the export vector tiles task.
        /// - Returns: A new `ArcGISVectorTiledLayer` object.
        private func makeOfflineVectorTiledLayer(
            itemID: String
        ) async throws -> ArcGISVectorTiledLayer {
            // Creates a export style resource cache job using a portal item.
            let portalItem = PortalItem(
                portal: .arcGISOnline(connection: .anonymous),
                id: .init(itemID)!
            )
            let exportTask = ExportVectorTilesTask(portalItem: portalItem)
            
            let temporaryURL = temporaryDirectoryURL.appendingPathComponent(itemID)
            let exportStyleResourceCacheJob = exportTask.makeExportStyleResourceCacheJob(
                itemResourceCacheURL: temporaryURL
            )
            
            // Gets the item resource cache from the job and uses it to create the layer.
            exportStyleResourceCacheJob.start()
            let output = try await exportStyleResourceCacheJob.output
            
            return ArcGISVectorTiledLayer(
                vectorTileCache: vectorTileCache,
                itemResourceCache: output.itemResourceCache
            )
        }
    }
}

// MARK: Helper Extensions

private extension FileManager {
    /// Creates a temporary directory.
    /// - Returns: The URL of the created directory
    static func createTemporaryDirectory() -> URL {
        // swiftlint:disable:next force_try
        try! FileManager.default.url(
            for: .itemReplacementDirectory,
            in: .userDomainMask,
            appropriateFor: FileManager.default.temporaryDirectory,
            create: true
        )
    }
}

private extension URL {
    /// The URL to the local vector tile package file with Dodge City, KS data.
    static var dodgeCityVectorTilePackage: URL {
        Bundle.main.url(forResource: "dodge_city", withExtension: "vtpk")!
    }
}
