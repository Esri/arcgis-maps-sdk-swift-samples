// Copyright 2023 Esri
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

struct IdentifyRasterCellView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// The screen point of where the user tapped.
    @State private var tapScreenPoint: CGPoint?
    
    var body: some View {
        MapViewReader { mapViewProxy in
            MapView(map: model.map)
                .callout(placement: $model.calloutPlacement
                    .animation(model.calloutShouldOffset ? nil : .default.speed(2))
                ) { _ in
                    Text(model.calloutText)
                        .font(.callout)
                        .padding(8)
                }
                .onSingleTapGesture { screenPoint, _ in
                    tapScreenPoint = screenPoint
                }
                .onLongPressAndDragGesture { screenPoint in
                    model.calloutShouldOffset = true
                    tapScreenPoint = screenPoint
                } onEnded: {
                    model.calloutShouldOffset = false
                }
                .task(id: EquatablePair(tapScreenPoint, model.calloutShouldOffset)) {
                    // Create a callout at the tap location.
                    if let tapScreenPoint {
                        await model.callout(at: tapScreenPoint, using: mapViewProxy)
                    }
                }
                .errorAlert(presentingError: $model.error)
        }
    }
}

private extension IdentifyRasterCellView {
    /// The view model for the sample.
    @MainActor
    class Model: ObservableObject {
        /// A map with a raster layer and an oceans basemap centered on Cape Town, South Africa.
        private(set) lazy var map: Map = {
            let map = Map(basemapStyle: .arcGISOceans)
            map.initialViewpoint = Viewpoint(latitude: -34.1, longitude: 18.6, scale: 1_155e3)
            map.addOperationalLayer(rasterLayer)
            return map
        }()
        
        /// The map's raster layer loaded from a local URL.
        private let rasterLayer = RasterLayer(raster: Raster(fileURL: .ndviRaster))
        
        /// The placement of the callout on the map.
        @Published var calloutPlacement: CalloutPlacement?
        
        /// The text shown on the callout.
        @Published private(set) var calloutText: String = ""
        
        /// A Boolean value that indicates whether the callout placement should be offsetted for the map magnifier.
        @Published var calloutShouldOffset = false
        
        /// The error shown in the error alert.
        @Published var error: Error?
        
        /// Creates a callout displaying the data of a raster cell at a given screen point.
        /// - Parameters:
        ///   - screenPoint: The screen point of the raster cell at which to place the callout.
        ///   - mapViewProxy: The proxy used to handle the screen point.
        func callout(at screenPoint: CGPoint, using proxy: MapViewProxy) async {
            // Get the raster cell for the screen point using the map view proxy.
            if let rasterCell = await rasterCell(at: screenPoint, using: proxy) {
                // Update the callout text and placement.
                updateCalloutText(using: rasterCell)
                updateCalloutPlacement(to: screenPoint, using: proxy)
            } else {
                // Dismiss the callout if no raster cell was found, e.g. tap was not on layer.
                calloutPlacement = nil
            }
        }
        
        /// Identifies the raster cell for a given screen point on the raster layer.
        /// - Parameters:
        ///   - screenPoint: The screen point corresponding to a raster cell.
        ///   - proxy: The proxy used to identify the screen point on the raster layer.
        /// - Returns: The first raster cell found in the identify result.
        private func rasterCell(at screenPoint: CGPoint, using proxy: MapViewProxy) async -> RasterCell? {
            do {
                // Identify the screen point on the raster layer using the map view proxy.
                let identifyResult = try await proxy.identify(on: rasterLayer, screenPoint: screenPoint, tolerance: 1)
                
                // Get the first raster cell from the identify result.
                let rasterCell = identifyResult.geoElements.first(where: { $0 is RasterCell })
                return rasterCell as? RasterCell
            } catch {
                self.error = error
                return nil
            }
        }
        
        /// Updates the location of the callout placement to a given screen point.
        /// - Parameters:
        ///   - screenPoint: The screen point at which to place the callout.
        ///   - proxy: The proxy used to convert the screen point to a map point.
        private func updateCalloutPlacement(to screenPoint: CGPoint, using proxy: MapViewProxy) {
            // Create an offset to offset the callout if needed, e.g. the magnifier is showing.
            let offset = calloutShouldOffset ? CGPoint(x: 0, y: -70) : .zero
            
            // Get the map location of the screen point from the map view proxy.
            if let location = proxy.location(fromScreenPoint: screenPoint) {
                calloutPlacement = .location(location, offset: offset)
            }
        }
        
        /// Updates the text shown in the callout using the attributes and coordinates of a given raster cell.
        /// - Parameter cell: The raster cell to create the text from.
        private func updateCalloutText(using cell: RasterCell) {
            // Create the attributes text using the attributes of the raster cell.
            let attributes = cell.attributes
                .map { "\($0.key): \($0.value)" }
                .sorted(by: >)
                .joined(separator: "\n")
            
            // Create the coordinate texts using the extent of the cell's geometry.
            guard let extent = cell.geometry?.extent else {
                calloutText = attributes
                return
            }
            let roundedStyle = FloatingPointFormatStyle<Double>.number.rounded(rule: .awayFromZero, increment: 0.001)
            let xCoordinate = "X: \(extent.xMin.formatted(roundedStyle))"
            let yCoordinate = "Y: \(extent.yMin.formatted(roundedStyle))"
            
            // Update the callout text.
            calloutText = "\(attributes)\n\n\(xCoordinate)\n\(yCoordinate)"
        }
    }
    
    // A generic struct made up of two equatable types.
    struct EquatablePair<T: Equatable, U: Equatable>: Equatable {
        var t: T
        var u: U
        
        init(_ t: T, _ u: U) {
            self.t = t
            self.u = u
        }
    }
}

private extension MapView {
    /// Sets a closure to perform when the map view recognizes a long press and drag gesture.
    /// - Parameters:
    ///   - action: The closure to perform when the gesture is recognized.
    ///   - onEnded: The closure to perform when the long press or drag ends.
    /// - Returns: A new `View` object.
    func onLongPressAndDragGesture(
        perform action: @escaping (CGPoint) -> Void,
        onEnded: @escaping () -> Void
    ) -> some View {
        self
            .onLongPressGesture { screenPoint, _ in
                action(screenPoint)
            }
            .gesture(
                LongPressGesture()
                    .simultaneously(with: DragGesture())
                    .onEnded { value in
                        // Run the closure if there was a valid long press with the drag.
                        if value.first != nil {
                            onEnded()
                        }
                    }
            )
    }
}

private extension URL {
    /// A URL to the local NDVI classification raster file.
    static var ndviRaster: Self {
        Bundle.main.url(forResource: "SA_EVI_8Day_03May20", withExtension: "tif", subdirectory: "SA_EVI_8Day_03May20")!
    }
}
