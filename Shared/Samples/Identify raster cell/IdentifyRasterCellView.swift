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
    
    var body: some View {
        MapViewReader { mapViewProxy in
            MapView(map: model.map)
                .callout(placement: $model.calloutPlacement
                    .animation(model.calloutShouldAnimate ? .default.speed(2) : nil)
                ) { _ in
                    Text(model.calloutText)
                        .font(.callout)
                        .padding(8)
                }
                .onSingleTapGesture { screenPoint, _ in
                    // Create a callout at the tap location.
                    model.callout(at: screenPoint, using: mapViewProxy)
                }
                .onLongPressGesture { screenPoint, _ in
                    // Create a callout with an offset when the map magnifier is showing.
                    model.callout(at: screenPoint, using: mapViewProxy, withOffset: true)
                } onEnded: { screenPoint, _ in
                    // Update the callout to remove the offset when the gesture ends.
                    model.callout(at: screenPoint, using: mapViewProxy, withOffset: false)
                }
                .alert(isPresented: $model.isShowingErrorAlert, presentingError: model.error)
        }
    }
}

private extension IdentifyRasterCellView {
    /// The view model for the sample.
    @MainActor
    class Model: ObservableObject {
        /// A map with an oceans basemap centered on Cape Town, South Africa.
        let map: Map = {
            let map = Map(basemapStyle: .arcGISOceans)
            map.initialViewpoint = Viewpoint(latitude: -34.1, longitude: 18.6, scale: 1_155e3)
            return map
        }()
        
        /// The raster layer on the map.
        private let rasterLayer = RasterLayer(raster: Raster(fileURL: .ndviRaster))
        
        /// The placement of the callout on the map.
        @Published var calloutPlacement: CalloutPlacement?
        
        /// The text shown on the callout.
        @Published private(set) var calloutText: String = ""
        
        /// A Boolean value that indicates whether the callout placement should be animated.
        @Published private(set) var calloutShouldAnimate = false
        
        /// A Boolean value that indicates whether to show an error alert.
        @Published var isShowingErrorAlert = false
        
        /// The error shown in the error alert.
        @Published private(set) var error: Error? {
            didSet { isShowingErrorAlert = error != nil }
        }
        
        init() {
            loadRasterLayer()
        }
        
        /// Loads a raster layer from a URL.
        func loadRasterLayer() {
            Task { [weak self] in
                guard let self else { return }
                
                do {
                    // Create a raster with the local file URL.
                    let raster = Raster(fileURL: .ndviRaster)
                    
                    // Create a raster layer using the raster.
                    rasterLayer = RasterLayer(raster: raster)
                    
                    // Load the layer before adding it to the map.
                    try await rasterLayer?.load()
                    
                    // Add the raster layer to the map as an operational layer.
                    if let rasterLayer {
                        map.addOperationalLayer(rasterLayer)
                    } else {
                        throw CustomError.message("No raster layer to add to the map.")
                    }
                } catch {
                    self.error = error
                }
            }
        }
        
        /// Creates a callout displaying the data of a raster cell at a given screen point.
        /// - Parameters:
        ///   - screenPoint: The screen point of the raster cell at which to place the callout.
        ///   - mapViewProxy: The proxy used to handle the screen point.
        ///   - withOffset: A Boolean value that indicates whether to offset the callout's placement.
        func callout(at screenPoint: CGPoint, using proxy: MapViewProxy, withOffset: Bool = false) {
            Task { [weak self] in
                guard let self else { return }
                
                // Get the raster cell for the screen point using the map view proxy.
                if let rasterCell = await rasterCell(for: screenPoint, using: proxy) {
                    // Update the callout text and placement.
                    updateCalloutText(using: rasterCell)
                    updateCalloutPlacement(to: screenPoint, using: proxy, offsetted: withOffset)
                } else {
                    // Dismiss the callout if no raster cell was found, e.g. tap was not on layer.
                    calloutPlacement = nil
                }
            }
        }
        
        /// Identifies the raster cell for a given screen point on the raster layer.
        /// - Parameters:
        ///   - screenPoint: The screen point corresponding to a raster cell.
        ///   - proxy: The proxy used to identify the screen point on the raster layer.
        /// - Returns: The first raster cell found in the identify result.
        private func rasterCell(for screenPoint: CGPoint, using proxy: MapViewProxy) async -> RasterCell? {
            do {
                guard let rasterLayer else {
                    throw CustomError.message("Raster layer is not initialized.")
                }
                
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
        ///   - offsetted: A Boolean value that indicates whether to offset the callout.
        private func updateCalloutPlacement(to screenPoint: CGPoint, using proxy: MapViewProxy, shouldUseOffset: Bool) {
            // Create an offset to offset the callout if needed, e.g. the magnifier is showing.
            let offset = offsetted ? CGPoint(x: 0, y: -70) : .zero
            
            // Disable the placement animation when there is an offset.
            // This is done to prevent the callout from lagging when the magnifier is moved.
            calloutShouldAnimate = !offsetted
            
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
            let xCoordinate = "X: \(extent.xMin.formatted(.rounded))"
            let yCoordinate = "Y: \(extent.yMin.formatted(.rounded))"
            
            // Update the callout text.
            calloutText = "\(attributes)\n\n\(xCoordinate)\n\(yCoordinate)"
        }
    }
    
    /// An enumeration used to throw an error customized with a string.
    enum CustomError: LocalizedError {
        case message(String)
        
        /// The text description of the error.
        var errorDescription: String? {
            if case .message(let string) = self {
                return NSLocalizedString(string, comment: "The description of the error thrown.")
            }
            return nil
        }
    }
}

/// An extension to add an on ended closure to the on long press gesture of the map view.
private extension MapView {
    /// The current screen point of a gesture.
    static var gestureScreenPoint = CGPoint()
    /// The current map point of a gesture.
    static var gestureMapPoint = Point(x: 0, y: 0)
    
    /// Sets a closure to perform when the map view recognizes a long press gesture.
    /// - Parameters:
    ///   - action: The closure to perform when a long press is recognized.
    ///   - onEnded: The closure to perform when the long press ends.
    /// - Returns: A new `View` object.
    func onLongPressGesture(perform action: @escaping (CGPoint, Point) -> Void, onEnded: ((CGPoint, Point?) -> Void)? = nil) -> some View {
        self
            .onLongPressGesture { screenPoint, mapPoint in
                Self.gestureScreenPoint = screenPoint
                Self.gestureMapPoint = mapPoint
                
                action(screenPoint, mapPoint)
            }
            .gesture(
                LongPressGesture()
                    .simultaneously(with: DragGesture())
                    .onEnded { value in
                        guard let onEnded else { return }
                        
                        if value.first != nil {
                            onEnded(Self.gestureScreenPoint, Self.gestureMapPoint)
                        }
                    }
            )
    }
}

private extension FormatStyle where Self == FloatingPointFormatStyle<Double> {
    /// The format style for rounding a decimal to three places.
    static var rounded: Self {
        .number.rounded(rule: .awayFromZero, increment: 0.001)
    }
}

private extension URL {
    /// A URL to the local NDVI classification raster file.
    static var ndviRaster: Self {
        Bundle.main.url(forResource: "SA_EVI_8Day_03May20", withExtension: "tif", subdirectory: "SA_EVI_8Day_03May20")!
    }
}
