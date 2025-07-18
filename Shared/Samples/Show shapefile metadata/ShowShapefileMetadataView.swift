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
    @State private var model = Model()
    /// The error that occurred, if any, when trying to save the map to the portal.
    @State private var error: Error?
    
    @State private var showMetadata: Bool = false
    
    var body: some View {
        MapViewReader { mapView in
            ZStack {
                MapView(map: model.map)
                if showMetadata {
                    MetadataView(model: $model)
                }
            }
            .onAppear {
                Task {
                    do {
                        try await model.loadFeatureLayer()
                        if let fullExtent = model.featureLayer?.fullExtent {
                            try await mapView.setViewpointGeometry(fullExtent, padding: 50)
                        }
                    } catch {
                        self.error = error
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button(showMetadata ? "Hide Metadata" : "Show Metadata") {
                        self.showMetadata.toggle()
                    }
                }
            }
            .errorAlert(presentingError: $error)
        }
    }
}

private extension ShowShapefileMetadataView {
    @MainActor
    @Observable
    class Model {
        // Create a map with a topographic basemap.
        var map = Map(basemapStyle: .arcGISTopographic)
        var featureLayer: FeatureLayer?
        var shapefileInfo: ShapefileInfo?
        var thumbnailImage: UIImage?
        
        func loadFeatureLayer() async throws {
            // Create a shapefile feature table.
            let featureTable = ShapefileFeatureTable(
                fileURL: Bundle.main.url(
                    forResource: "TrailBikeNetwork",
                    withExtension: "shp",
                    subdirectory: "Aurora_CO_shp"
                )!
            )
            featureLayer = FeatureLayer(featureTable: featureTable)
            try await featureLayer!.featureTable?.load()
            map.addOperationalLayer(featureLayer!)
            shapefileInfo = featureTable.info
            thumbnailImage = featureTable.info?.thumbnail
        }
    }
    
    struct MetadataView: View {
        @Binding var model: ShowShapefileMetadataView.Model
        
        var body: some View {
            VStack(alignment: .center, spacing: 16) {
                Text("\(model.shapefileInfo?.credits ?? "")")
                    .fontWeight(.bold)
                Text("\(model.shapefileInfo?.summary ?? "")")
                    .font(.caption)
                if let image = model.thumbnailImage {
                    Image(uiImage: image)
                }
                Text("Tags: \(model.shapefileInfo?.tags.joined(separator: ", ") ?? "None")")
                    .font(.caption2)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
            .padding(.horizontal)
        }
    }
}

#Preview {
    ShowShapefileMetadataView()
}
