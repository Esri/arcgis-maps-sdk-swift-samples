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
import TipKit

struct NavigateMapAndIdentifyFeaturesWithVoiceControlView: View {
    /// The view model for the sample.
    @State private var model = Model()
    
    /// The error shown in the error alert.
    @State private var error: (any Error)?
    
    /// A Boolean value indicating whether the initial draw has completed.
    @State private var initialDrawCompleted = false
    
    /// The placement of the restaurant details callout.
    @State private var calloutPlacement: CalloutPlacement?
    
    /// The feature shown in the callout.
    @State private var calloutFeature: Feature?
    
    /// The status message shown for voice control and selection feedback.
    @State private var statusMessage = ""

    /// A task for delayed selection refresh after navigation ends.
    @State private var refreshTask: Task<Void, Never>?
    
    /// The side length of the centered area-of-interest rectangle, in screen points.
    private let selectionRectangleLength: CGFloat = 420
    
    /// The fraction of the map width used for each horizontal voice-command pan.
    private let horizontalPanStepRatio: CGFloat = 0.2

    /// The fraction of the map height used for each vertical voice-command pan.
    private let verticalPanStepRatio: CGFloat = 0.2
    
    var body: some View {
        MapViewReader { mapViewProxy in
            GeometryReader { geometryProxy in
                let mapSize = geometryProxy.size
                let rectangleLength = min(selectionRectangleLength, min(mapSize.width, mapSize.height))
                
                MapView(map: model.map, graphicsOverlays: [model.labelOverlay])
                    .selectionColor(Model.selectionHaloColor)
                    .callout(placement: $calloutPlacement.animation(.default.speed(2))) { _ in
                        if let calloutFeature {
                            makeCalloutContent(feature: calloutFeature)
                        }
                    }
                    .onDrawStatusChanged { drawStatus in
                        guard drawStatus == .completed, !initialDrawCompleted else { return }
                        initialDrawCompleted = true
                        Task {
                            do {
                                // Ensure feature layer is fully loaded before querying
                                try await model.ensureLayerLoaded()
                                
                                // Additional delay to ensure map view proxy is fully ready and settled
                                try? await Task.sleep(for: .milliseconds(500))
                                await refreshSelection(mapSize: mapSize, mapViewProxy: mapViewProxy)
                            } catch {
                                self.error = error
                            }
                        }
                    }
                    .onNavigatingChanged { navigating in
                        if navigating {
                            dismissCallout()
                            // Cancel any pending refresh when navigation starts
                            refreshTask?.cancel()
                        } else if initialDrawCompleted {
                            // Cancel any previous pending refresh
                            refreshTask?.cancel()
                            
                            // Debounce: wait for map to fully settle after navigation
                            refreshTask = Task {
                                // Wait for coordinate transforms to stabilize
                                try? await Task.sleep(for: .milliseconds(200))
                                
                                guard !Task.isCancelled else { return }
                                
                                await refreshSelection(mapSize: mapSize, mapViewProxy: mapViewProxy)
                            }
                        }
                    }
                    .overlay(alignment: .center) {
                        if calloutPlacement == nil {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.pink.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(.pink, lineWidth: 2)
                                )
                                .frame(width: rectangleLength, height: rectangleLength)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }
                    }
                    .overlay(alignment: .top) {
                        TipView(AreaOfInterestTip())
                    }
                    .overlay(alignment: .bottom) {
                        VStack(spacing: 8) {
                            if model.hasMoreThanNineSelectedFeatures {
                                Text("More than 9 restaurants are in the search area. Zoom in or pan to narrow the results.")
                                    .font(.footnote)
                                    .multilineTextAlignment(.center)
                                    .padding(8)
                                    .background(.regularMaterial)
                                    .clipShape(.rect(cornerRadius: 8))
                            }
                            if !statusMessage.isEmpty {
                                Text(statusMessage)
                                    .font(.footnote)
                                    .multilineTextAlignment(.center)
                                    .padding(8)
                                    .background(.regularMaterial)
                                    .clipShape(.rect(cornerRadius: 8))
                            }
                            makeVoiceControlBar(mapSize: mapSize, mapViewProxy: mapViewProxy)
                        }
                        .padding(.bottom)
                    }
                    .onAppear {
                        // TipKit configuration is intended to happen once per process.
                        // Avoid showing an alert if this view appears multiple times.
                        try? Tips.configure([.displayFrequency(.immediate)])
                    }
                    .overlay(alignment: .bottomTrailing) {
                        TipView(VoiceCommandTip())
                    }
                    .errorAlert(presentingError: $error)
            }
        }
    }
    
    /// Refreshes the selected and numbered restaurant features for the current rectangle.
    @MainActor
    private func refreshSelection(mapSize: CGSize, mapViewProxy: MapViewProxy) async {
        do {
            try await model.selectFeatures(
                in: makeSelectionEnvelope(mapSize: mapSize, mapViewProxy: mapViewProxy),
                screenPointFor: { mapViewProxy.screenPoint(fromLocation: $0) }
            )
        } catch {
            self.error = error
        }
    }
    
    /// Makes an envelope matching the centered selection rectangle's map footprint.
    private func makeSelectionEnvelope(mapSize: CGSize, mapViewProxy: MapViewProxy) -> Envelope? {
        let clampedRectangleLength = min(selectionRectangleLength, min(mapSize.width, mapSize.height))
        let screenCenter = CGPoint(x: mapSize.width / 2, y: mapSize.height / 2)
        let halfLength = clampedRectangleLength / 2
        
        // Sample all four corners of the rectangle to ensure complete coverage
        let topLeft = CGPoint(x: screenCenter.x - halfLength, y: screenCenter.y - halfLength)
        let topRight = CGPoint(x: screenCenter.x + halfLength, y: screenCenter.y - halfLength)
        let bottomRight = CGPoint(x: screenCenter.x + halfLength, y: screenCenter.y + halfLength)
        let bottomLeft = CGPoint(x: screenCenter.x - halfLength, y: screenCenter.y + halfLength)
        
        // Convert all corners to map coordinates
        let corners = [topLeft, topRight, bottomRight, bottomLeft]
        let mapPoints = corners.compactMap { mapViewProxy.location(fromScreenPoint: $0) }
        
        // Ensure we got all 4 corners converted
        guard mapPoints.count == 4,
              let spatialReference = mapPoints.first?.spatialReference else {
            return nil
        }
        
        // Find the bounding envelope that encompasses all corners
        let xValues = mapPoints.map(\.x)
        let yValues = mapPoints.map(\.y)
        
        guard let minX = xValues.min(),
              let maxX = xValues.max(),
              let minY = yValues.min(),
              let maxY = yValues.max() else {
            return nil
        }
        
        return Envelope(
            xRange: minX...maxX,
            yRange: minY...maxY,
            spatialReference: spatialReference
        )
    }
    
    /// Pans the map left or right by shifting the center point by a screen-space offset.
    @MainActor
    private func panHorizontally(direction: CGFloat, mapSize: CGSize, mapViewProxy: MapViewProxy) async {
        dismissCallout()

        let centerScreenPoint = CGPoint(x: mapSize.width / 2, y: mapSize.height / 2)
        let horizontalOffset = mapSize.width * horizontalPanStepRatio * direction
        let targetScreenPoint = CGPoint(x: centerScreenPoint.x + horizontalOffset, y: centerScreenPoint.y)

        guard let targetCenterPoint = mapViewProxy.location(fromScreenPoint: targetScreenPoint) else {
            return
        }

        await mapViewProxy.setViewpointCenter(targetCenterPoint)
    }

    /// Pans the map up or down by shifting the center point by a screen-space offset.
    @MainActor
    private func panVertically(direction: CGFloat, mapSize: CGSize, mapViewProxy: MapViewProxy) async {
        dismissCallout()

        let centerScreenPoint = CGPoint(x: mapSize.width / 2, y: mapSize.height / 2)
        let verticalOffset = mapSize.height * verticalPanStepRatio * direction
        let targetScreenPoint = CGPoint(x: centerScreenPoint.x, y: centerScreenPoint.y + verticalOffset)

        guard let targetCenterPoint = mapViewProxy.location(fromScreenPoint: targetScreenPoint) else {
            return
        }

        await mapViewProxy.setViewpointCenter(targetCenterPoint)
    }
    
    /// Shows the details callout for the selected numbered feature.
    private func showCalloutForFeature(at index: Int) {
        guard let feature = model.numberedFeatures[safe: index],
              let anchor = feature.geometry as? Point else {
            statusMessage = "No restaurant is assigned to \(index + 1)."
            calloutFeature = nil
            calloutPlacement = nil
            return
        }
        
        statusMessage = ""
        calloutFeature = feature
        calloutPlacement = .geoElement(feature, tapLocation: anchor)
    }
    
    /// Dismisses the details callout and restores the selection rectangle.
    private func dismissCallout() {
        calloutFeature = nil
        calloutPlacement = nil
        statusMessage = ""
    }

    /// A set of visible controls that can be activated through iOS Accessibility Voice Control.
    private func makeVoiceControlBar(mapSize: CGSize, mapViewProxy: MapViewProxy) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button("Pan Left") {
                    Task { await panHorizontally(direction: -1, mapSize: mapSize, mapViewProxy: mapViewProxy) }
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Pan Left")

                Button("Pan Right") {
                    Task { await panHorizontally(direction: 1, mapSize: mapSize, mapViewProxy: mapViewProxy) }
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Pan Right")

                Button("Pan Up") {
                    Task { await panVertically(direction: -1, mapSize: mapSize, mapViewProxy: mapViewProxy) }
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Pan Up")

                Button("Pan Down") {
                    Task { await panVertically(direction: 1, mapSize: mapSize, mapViewProxy: mapViewProxy) }
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Pan Down")
            }

            HStack(spacing: 8) {
                ForEach(1...9, id: \.self) { number in
                    Button("\(number)") {
                        showCalloutForFeature(at: number - 1)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Restaurant \(number)")
                }
                Button("Dismiss") {
                    dismissCallout()
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Dismiss")
            }
        }
    }
    
    /// The callout content for a restaurant feature.
    private func makeCalloutContent(feature: Feature) -> some View {
        let anchor = feature.geometry as? Point
        let wgs84Point = anchor.flatMap { GeometryEngine.project($0, into: .wgs84) }
        
        return VStack(alignment: .leading) {
            Text(model.name(for: feature, fallback: "Restaurant") ?? "Restaurant")
                .font(.headline)
            if let wgs84Point {
                Text("Lat: \(wgs84Point.y, format: .number.precision(.fractionLength(6)))")
                Text("Lon: \(wgs84Point.x, format: .number.precision(.fractionLength(6)))")
            }
        }
        .padding(5)
    }
}

private extension NavigateMapAndIdentifyFeaturesWithVoiceControlView {
    /// A TipKit tip that explains the centered rectangle.
    struct AreaOfInterestTip: Tip {
        var title: Text {
            Text("Use the rectangle as the search area")
        }
        
        var message: Text? {
            Text(
                """
                 Pan until the restaurants you want to inspect are inside the rectangle. With Accessibility Voice Control enabled, say commands like “Tap Pan Left”, “Tap Pan Up”, or “Tap Restaurant 1” through “Tap Restaurant 9”.
                 """
            )
        }
        
        var image: Image? {
            Image(systemName: "rectangle.dashed")
        }
    }
    
    struct VoiceCommandTip: Tip {
        var title: Text {
            Text("Use Accessibility Voice Control")
        }
        
        var message: Text? {
            Text(
                """
                Enable Voice Control in Settings > Accessibility > Voice Control.
                Then say commands like “Tap Pan Left” or “Tap Restaurant 3”.
                """
            )
        }
        
        var image: Image? {
            Image(systemName: "mic")
        }
    }
}

private extension Collection {
    /// Returns the element at the index if it exists.
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    NavigationStack {
        NavigateMapAndIdentifyFeaturesWithVoiceControlView()
    }
}


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
import Foundation
import SwiftUI
import UIKit.UIColor

extension NavigateMapAndIdentifyFeaturesWithVoiceControlView {
    /// The model for the sample.
    @MainActor
    @Observable
    final class Model {
        /// The maximum number of features that can be identified with number keys.
        private static let maximumNumberedFeatures = 9
        
        /// Buffer distance around the selection envelope to account for edge cases.
        private static let selectionBufferDistance = LinearUnit.meters.convert(to: .meters, value: 60)
        
        /// Attribute used to title and label each feature.
        private static let nameAttribute = "name"
        
        /// Colors used for the marker, selection halo, and label.
        private static let markerFillColor = UIColor(red: 11 / 255, green: 79 / 255, blue: 138 / 255, alpha: 1)
        static let selectionHaloColor = Color(red: 190 / 255, green: 24 / 255, blue: 93 / 255)
        private static let labelTextColor = UIColor(red: 31 / 255, green: 35 / 255, blue: 40 / 255, alpha: 1)
        
        /// The map displayed in the map view.
        let map: Map
        
        /// The feature table of restaurants in Redlands.
        private let restaurantsTable = ServiceFeatureTable(url: .redlandsRestaurants)
        
        /// The feature layer holding the restaurants displayed and identified by the sample.
        private let restaurantsLayer: FeatureLayer
        
        /// The overlay for the numbered 1-9 labels.
        let labelOverlay = GraphicsOverlay()
        
        /// Features currently in the area of interest, indexed by the matching number key.
        private(set) var numberedFeatures: [Feature] = []
        
        /// A Boolean value indicating whether more than nine features are selected.
        private(set) var hasMoreThanNineSelectedFeatures = false
        
        init() {
            restaurantsLayer = FeatureLayer(featureTable: restaurantsTable)
            restaurantsLayer.renderer = SimpleRenderer(symbol: Self.restaurantSymbol)
            
            let map = Map(basemapStyle: .arcGISLightGray)
            map.initialViewpoint = Viewpoint(
                center: Point(x: -117.1825, y: 34.0556, spatialReference: .wgs84),
                scale: 4_000
            )
            map.addOperationalLayer(restaurantsLayer)
            self.map = map
        }
        
        /// Ensures the feature table is fully loaded before querying.
        func ensureLayerLoaded() async throws {
            // Load the feature table to ensure metadata and features are available
            try await restaurantsTable.load()
        }
        
        /// Selects, numbers, and labels restaurant features that intersect a given envelope.
        /// - Parameters:
        ///   - envelope: The envelope used to query restaurant features.
        ///   - screenPointFor: A closure that converts a map location to a screen point.
        func selectFeatures(in envelope: Envelope?, screenPointFor: (Point) -> CGPoint?) async throws {
            clearSelection()
            
            guard let envelope else { return }
            
            let orderedFeatures = try await makeOrderedFeatures(intersecting: envelope)
            
            hasMoreThanNineSelectedFeatures = orderedFeatures.count > Self.maximumNumberedFeatures
            
            // Only select the numbered features (first 9)
            let numberedOrderedFeatures = orderedFeatures.prefix(Self.maximumNumberedFeatures)
            restaurantsLayer.selectFeatures(numberedOrderedFeatures.map(\.feature))
            
            addNumberedLabels(for: orderedFeatures)
        }
        
        /// Clears selected features, label graphics, and numbered feature state.
        func clearSelection() {
            restaurantsLayer.clearSelection()
            labelOverlay.removeAllGraphics()
            numberedFeatures.removeAll()
            hasMoreThanNineSelectedFeatures = false
        }
        
        /// Reads the feature's name attribute, returning the fallback when it is missing or blank.
        /// - Parameters:
        ///   - feature: The feature whose name is read.
        ///   - fallback: The value to return when the feature has no name.
        /// - Returns: The feature's name, or the fallback if no name exists.
        func name(for feature: Feature, fallback: String?) -> String? {
            guard let name = feature.attributes[Self.nameAttribute] as? String,
                  !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return fallback
            }
            return name
        }
        
        /// Queries and sorts restaurant features from top-to-bottom, then left-to-right in geographic space.
        /// - Parameter envelope: The envelope used to query restaurant features.
        /// - Returns: The ordered restaurant features with their map positions.
        private func makeOrderedFeatures(intersecting envelope: Envelope) async throws -> [OrderedFeature] {
            // Add a buffer to catch features near the rectangle edges.
            // This accounts for projection distortions and rendering tolerances.
            let bufferedEnvelope = GeometryEngine.buffer(around: envelope, distance: Self.selectionBufferDistance)?.extent ?? envelope
            
            let queryParameters = QueryParameters()
            queryParameters.geometry = bufferedEnvelope
            queryParameters.spatialRelationship = .intersects
            queryParameters.maxFeatures = 1000
            
            let queryResult = try await restaurantsTable.queryFeatures(using: queryParameters)
            let allFeatures = Array(queryResult.features())
            
            return allFeatures
                .compactMap { feature -> OrderedFeature? in
                    guard let anchor = feature.geometry as? Point else { return nil }
                    return OrderedFeature(feature: feature, anchor: anchor)
                }
                .sorted { lhs, rhs in
                    // Sort by geographic coordinates (north to south, then west to east).
                    if lhs.anchor.y != rhs.anchor.y {
                        return lhs.anchor.y > rhs.anchor.y
                    }
                    return lhs.anchor.x < rhs.anchor.x
                }
        }
        
        /// Adds numbered text labels for the first restaurant features.
        /// - Parameter orderedFeatures: The ordered restaurant features to label.
        private func addNumberedLabels(for orderedFeatures: [OrderedFeature]) {
            let numberedOrderedFeatures = orderedFeatures.prefix(Self.maximumNumberedFeatures)
            
            for (offset, orderedFeature) in numberedOrderedFeatures.enumerated() {
                let number = offset + 1
                let text = name(for: orderedFeature.feature, fallback: nil).map { "\(number): \($0)" } ?? "\(number)"
                let labelSymbol = TextSymbol(
                    text: text,
                    color: Self.labelTextColor,
                    size: 15,
                    horizontalAlignment: .center,
                    verticalAlignment: .top
                )
                labelSymbol.haloColor = .white
                labelSymbol.haloWidth = 2
                labelSymbol.offsetY = -14
                labelOverlay.addGraphic(Graphic(geometry: orderedFeature.anchor, symbol: labelSymbol))
                numberedFeatures.append(orderedFeature.feature)
            }
        }
        
        /// The restaurant marker symbol.
        private static var restaurantSymbol: SimpleMarkerSymbol {
            let symbol = SimpleMarkerSymbol(style: .circle, color: markerFillColor, size: 12)
            symbol.outline = SimpleLineSymbol(style: .solid, color: .white, width: 1.5)
            return symbol
        }
        
        /// A feature and its map location.
        private struct OrderedFeature {
            let feature: Feature
            let anchor: Point
        }
    }
}

private extension URL {
    /// The URL of the Redlands restaurants feature service.
    static var redlandsRestaurants: URL {
        URL(string: "https://services2.arcgis.com/ZQgQTuoyBrtmoGdP/arcgis/rest/services/redlands_food/FeatureServer/0")!
    }
}
