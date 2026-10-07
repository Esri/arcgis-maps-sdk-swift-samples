// Copyright 2026 Esri
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

struct FilterMosaicDatasetRasterByTimeExtentView: View {
    /// The map displayed in the view.
    @State private var map = Map(basemapStyle: .arcGISLightGrayBase)
    /// The time extent used to filter the mosaic dataset raster.
    @State private var timeExtent: TimeExtent?
    /// The timestamps from the mosaic dataset raster.
    @State private var timestamps: [Date] = []
    /// The index of the currently selected timestamp.
    @State private var selectedIndex = 0
    /// A Boolean value indicating whether the raster is loading.
    @State private var isLoading = true
    /// The error shown in the error alert.
    @State private var loadError: (any Error)?
    /// The height of the attribution bar at the bottom of the map view.
    @State private var attributionBarHeight: CGFloat?
    
    var body: some View {
        MapViewReader { mapViewProxy in
            MapView(map: map, timeExtent: $timeExtent)
                .onAttributionBarHeightChanged { height in
                    withAnimation { attributionBarHeight = height }
                }
                .overlay(alignment: .bottom) {
                    HStack {
                        Button("Previous timestamp", systemImage: "chevron.left") {
                            selectTimestamp(at: selectedIndex - 1)
                        }
                        .labelStyle(.iconOnly)
                        .disabled(timestamps.isEmpty || selectedIndex <= 0)
                        
                        Divider()
                        
                        if isLoading {
                            HStack {
                                ProgressView()
                                Text("Loading…")
                            }
                        } else if timestamps.indices.contains(selectedIndex) {
                            Text(
                                timestamps[selectedIndex],
                                format: .dateTime.month(.twoDigits).day(.twoDigits).year()
                            )
                            .monospacedDigit()
                        } else {
                            Text("No timestamps available")
                        }
                        
                        Divider()
                        
                        Button("Next timestamp", systemImage: "chevron.right") {
                            selectTimestamp(at: selectedIndex + 1)
                        }
                        .labelStyle(.iconOnly)
                        .disabled(timestamps.isEmpty || selectedIndex >= timestamps.count - 1)
                    }
                    .frame(height: 44)
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.bottom, 16)
                    .padding(.bottom, attributionBarHeight)
                }
                .task {
                    do {
                        isLoading = true
                        defer { isLoading = false }
                        try await loadRaster(mapViewProxy: mapViewProxy)
                    } catch {
                        loadError = error
                    }
                }
                .errorAlert(presentingError: $loadError)
        }
    }
    
    /// Sets the time extent to the timestamp at the specified index.
    /// - Parameter index: The index of the timestamp to select.
    private func selectTimestamp(at index: Int) {
        guard timestamps.indices.contains(index) else {
            fatalError("Index \(index) is out of bounds for timestamps array.")
        }
        selectedIndex = index
        timeExtent = TimeExtent(date: timestamps[index])
    }
    
    /// Loads the mosaic dataset raster and adds it to the map.
    /// - Parameter mapViewProxy: The map view.
    private func loadRaster(mapViewProxy: MapViewProxy) async throws {
        guard let databaseURL = Bundle.main.url(
            forResource: "el_toro",
            withExtension: "geodatabase",
            subdirectory: "ElToroMosaicDataset"
        ) else {
            throw CocoaError(.fileNoSuchFile)
        }
        let rasterName = MosaicDatasetRaster.names(fromDatabaseAt: databaseURL).first ?? databaseURL.deletingPathExtension().lastPathComponent
        let raster = MosaicDatasetRaster(databaseURL: databaseURL, name: rasterName)
        let layer = RasterLayer(raster: raster)
        try await layer.load()
        
        timestamps = try await raster.distinctTimestamps
        map.addOperationalLayer(layer)
        
        if let fullExtent = layer.fullExtent {
            await mapViewProxy.setViewpointGeometry(fullExtent, padding: 100)
        }
        
        selectTimestamp(at: 0)
    }
}
