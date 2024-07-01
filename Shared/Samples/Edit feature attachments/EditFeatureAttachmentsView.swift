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

struct EditFeatureAttachmentsView: View {
    /// The error shown in the error alert.
    @State private var error: Error?
    
    @State private var tapPoint: CGPoint?
    
    /// The data model for the sample.
    @StateObject private var model = Model()
    
    
    
    var body: some View {
        MapViewReader { mapProxy in
            MapView(map: model.map)
                .callout(placement: $model.calloutPlacement
                    .animation(model.calloutShouldOffset ? nil : .default.speed(2))
                ) { _ in
                    Text(model.calloutText)
                        .font(.callout)
                        .padding(8)
                }
                .onSingleTapGesture { tap, _ in
                    self.tapPoint = tap
                }
                .task(id: tapPoint) {
                    guard let point = tapPoint else { return }
                    model.featureLayer.clearSelection()
                    do {
                        let result = try await mapProxy.identify(on: model.featureLayer, screenPoint: point, tolerance: 12)
                        guard let feature = result.geoElements.first as? ArcGISFeature else { return }
                        model.featureLayer.selectFeature(feature)
                        let title = feature.attributes["typdamage"] as? String
                        
                        model.updateCalloutPlacement(to: point, using: mapProxy)
                        model.calloutText = title ?? "Callout"
                        try await feature.load()
                        var attachments = try await feature.attachments
                        model.selectedFeature = feature
                        print(feature.attributes)
                        print(feature.canEditAttachments)
                    } catch {
                        self.error = error
                    }
                }
        }
        .errorAlert(presentingError: $error)
    }
}

private extension EditFeatureAttachmentsView {
    @MainActor
    class Model: ObservableObject {
        let map: Map = {
            let map = Map(basemapStyle: .arcGISOceans)
            map.initialViewpoint = Viewpoint(
                center: Point(x: 0, y: 0, spatialReference: .webMercator),
                scale: 100_000_000
            )
            return map
        }()
        
        /// The placement of the callout on the map.
        @Published var calloutPlacement: CalloutPlacement?
        
        @Published var selectedFeature: ArcGISFeature?
        
        /// The text shown on the callout.
        @Published var calloutText: String = ""
        
        /// A Boolean value that indicates whether the callout placement should be offsetted for the map magnifier.
        @Published var calloutShouldOffset = false
        
        var featureLayer: FeatureLayer = {
            let featureServiceURL = URL(string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/DamageAssessment/FeatureServer/0")!
            let featureTable = ServiceFeatureTable(url: featureServiceURL)
            var featureLayer = FeatureLayer(featureTable: featureTable)
            return featureLayer
        }()
        
        init() {
            map.addOperationalLayer(featureLayer)
        }
        
//        /// Creates a callout displaying the data of a raster cell at a given screen point.
//        /// - Parameters:
//        ///   - screenPoint: The screen point of the raster cell at which to place the callout.
//        ///   - mapViewProxy: The proxy used to handle the screen point.
//        func callout(at screenPoint: CGPoint, using proxy: MapViewProxy) async {
//            // Get the raster cell for the screen point using the map view proxy.
//            if let rasterCell = await rasterCell(at: screenPoint, using: proxy) {
//                // Update the callout text and placement.
//                updateCalloutText(using: rasterCell)
//                updateCalloutPlacement(to: screenPoint, using: proxy)
//            } else {
//                // Dismiss the callout if no raster cell was found, e.g. tap was not on layer.
//                calloutPlacement = nil
//            }
//        }
        
        /// Updates the location of the callout placement to a given screen point.
        /// - Parameters:
        ///   - screenPoint: The screen point at which to place the callout.
        ///   - proxy: The proxy used to convert the screen point to a map point.
        func updateCalloutPlacement(to screenPoint: CGPoint, using proxy: MapViewProxy) {
            // Create an offset to offset the callout if needed, e.g. the magnifier is showing.
            let offset = calloutShouldOffset ? CGPoint(x: 0, y: -70) : .zero
            
            // Get the map location of the screen point from the map view proxy.
            if let location = proxy.location(fromScreenPoint: screenPoint) {
                calloutPlacement = .location(location, offset: offset)
            }
        }
        
//        /// Updates the text shown in the callout using the attributes and coordinates of a given raster cell.
//        /// - Parameter cell: The raster cell to create the text from.
//        private func updateCalloutText(using cell: RasterCell) {
//            // Create the attributes text using the attributes of the raster cell.
//            let attributes = cell.attributes
//                .map { "\($0.key): \($0.value)" }
//                .sorted(by: >)
//                .joined(separator: "\n")
//            
//            // Create the coordinate texts using the extent of the cell's geometry.
//            guard let extent = cell.geometry?.extent else {
//                calloutText = attributes
//                return
//            }
//            let roundedStyle = FloatingPointFormatStyle<Double>.number.rounded(rule: .awayFromZero, increment: 0.001)
//            let xCoordinate = "X: \(extent.xMin.formatted(roundedStyle))"
//            let yCoordinate = "Y: \(extent.yMin.formatted(roundedStyle))"
//            
//            // Update the callout text.
//            calloutText = "\(attributes)\n\n\(xCoordinate)\n\(yCoordinate)"
//        }
    }
}

#Preview {
    EditFeatureAttachmentsView()
}
