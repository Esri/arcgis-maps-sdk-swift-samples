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

struct ShowShapefileMetadataView: View {
    // Create a map with a topographic basemap.
    @State private var map = Map(basemapStyle: .arcGISTopographic)
    /// The error that occurred, if any, when trying to save the map to the portal.
    @State private var error: Error?
    
    var body: some View {
        MapViewReader { mapView in
            MapView(map: map)
                .onAppear {
                    Task {
                        // Create a shapefile feature table.
                        let featureTable = ShapefileFeatureTable(
                            fileURL: Bundle.main.url(forResource: "Subdivisions", withExtension: "shp", subdirectory: "Aurora_CO_shp")!
                        )
                        let featureLayer = FeatureLayer(featureTable: featureTable)
                        do {
                            var image = featureTable.info?.thumbnail
                            try await featureLayer.featureTable?.load()
                        } catch {
                            self.error = error
                        }
                    }
                }
        }
    }
}

private extension ShowShapefileMetadataView {
    
}


#Preview {
    ShowShapefileMetadataView()
}
