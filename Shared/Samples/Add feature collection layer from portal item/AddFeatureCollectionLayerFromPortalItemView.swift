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

struct AddFeatureCollectionLayerFromPortalItemView: View {
    /// A map with an ocean basemap style.
    @State private var map = Map(basemapStyle: .arcGISOceans)
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    var body: some View {
        MapView(map: map)
            .task {
                // Creates a portal item with portal item ID.
                let portalItem = PortalItem(
                    portal: .arcGISOnline(connection: .anonymous),
                    id: PortalItem.ID("32798dfad17942858d5eef82ee802f0b")!
                )
                do {
                    try await portalItem.load()
                    // Verifies that the item represents a feature collection.
                    if portalItem.kind == .featureCollection {
                        // Creates a feature collection from the item.
                        let featureCollection = FeatureCollection(item: portalItem)
                        // Creates a feature collection layer, referring to the
                        // feature collection.
                        let layer = FeatureCollectionLayer(featureCollection: featureCollection)
                        // Adds the feature collection layer to the map's
                        // operational layers.
                        map.addOperationalLayer(layer)
                    }
                } catch {
                    // Updates the error and shows an alert if any failure occurs.
                    self.error = error
                }
            }
            .errorAlert(presentingError: $error)
    }
}

#Preview {
    AddFeatureCollectionLayerFromPortalItemView()
}
