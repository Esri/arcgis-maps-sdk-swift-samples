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
import UIKit

struct NavigateMapAndIdentifyFeaturesWithKeyboardView: View {
    /// The view model for the sample.
    @State private var model = Model()
    
    /// The error shown in the error alert.
    @State private var error: (any Error)?
    
    /// A Boolean value indicating whether the map view is navigating.
    @State private var isNavigating = false
    
    /// A Boolean value indicating whether the initial draw has completed.
    @State private var initialDrawCompleted = false
    
    /// The placement of the restaurant details callout.
    @State private var calloutPlacement: CalloutPlacement?
    
    /// The feature shown in the callout.
    @State private var calloutFeature: Feature?
    
    /// The status message shown when a number key has no matching restaurant.
    @State private var statusMessage = ""
    
    /// The side length of the centered area-of-interest rectangle, in screen points.
    private let selectionRectangleLength: CGFloat = 420
    
    /// The number keys that can identify features.
    private let featureNumberKeys = CharacterSet(charactersIn: "123456789")
    
    var body: some View {
        MapViewReader { mapViewProxy in
            GeometryReader { geometryProxy in
                let mapSize = geometryProxy.size
                
                MapView(map: model.map, graphicsOverlays: [model.labelOverlay])
                    .selectionColor(Model.selectionHaloColor)
                    .callout(placement: $calloutPlacement.animation(.default.speed(2))) { _ in
                        if let calloutFeature {
                            calloutContent(for: calloutFeature)
                        }
                    }
                    .onDrawStatusChanged { drawStatus in
                        guard drawStatus == .completed else { return }
                        initialDrawCompleted = true
                    }
                    .onNavigatingChanged { navigating in
                        isNavigating = navigating
                        if navigating {
                            dismissCallout()
                        }
                    }
                    .task(id: initialDrawCompleted) {
                        guard initialDrawCompleted else { return }
                        await refreshSelection(mapSize: mapSize, mapViewProxy: mapViewProxy)
                    }
                    .task(id: isNavigating) {
                        guard !isNavigating, initialDrawCompleted else { return }
                        await refreshSelection(mapSize: mapSize, mapViewProxy: mapViewProxy)
                    }
                    .onKeyPress(.escape) {
                        dismissCallout()
                        return .handled
                    }
                    .onKeyPress(characters: featureNumberKeys) { keyPress in
                        guard let featureIndex = featureIndex(for: keyPress.characters) else {
                            return .ignored
                        }
                        showCalloutForFeature(at: featureIndex, mapViewProxy: mapViewProxy)
                        return .handled
                    }
                    .overlay(alignment: .center) {
                        if calloutPlacement == nil {
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(.pink, lineWidth: 2)
                                .background(.pink.opacity(0.08))
                                .frame(width: selectionRectangleLength, height: selectionRectangleLength)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }
                    }
                    .overlay(alignment: .top) {
                        instructionsOverlay
                    }
                    .overlay(alignment: .bottom) {
                        VStack(spacing: 8) {
                            if model.hasMoreThanNineSelectedFeatures {
                                overflowMessage
                            }
                            if !statusMessage.isEmpty {
                                statusMessageOverlay
                            }
                        }
                        .padding(.bottom)
                    }
                    .overlay {
                        keyboardInputField(mapViewProxy: mapViewProxy)
                    }
                    .errorAlert(presentingError: $error)
            }
        }
    }
    
    /// Refreshes the selected and numbered restaurant features for the current rectangle.
    private func refreshSelection(mapSize: CGSize, mapViewProxy: MapViewProxy) async {
        do {
            try await model.selectFeatures(
                in: selectionEnvelope(mapSize: mapSize, mapViewProxy: mapViewProxy),
                screenPointForLocation: { mapViewProxy.screenPoint(fromLocation: $0) }
            )
        } catch {
            self.error = error
        }
    }
    
    /// Creates an envelope matching the centered selection rectangle's map footprint.
    private func selectionEnvelope(mapSize: CGSize, mapViewProxy: MapViewProxy) -> Envelope? {
        let screenCenter = CGPoint(x: mapSize.width / 2, y: mapSize.height / 2)
        let rightScreenPoint = CGPoint(
            x: screenCenter.x + selectionRectangleLength / 2,
            y: screenCenter.y
        )
        
        guard let mapCenter = mapViewProxy.location(fromScreenPoint: screenCenter),
              let rightMapPoint = mapViewProxy.location(fromScreenPoint: rightScreenPoint),
              let spatialReference = mapCenter.spatialReference else {
            return nil
        }
        
        let halfWidth = abs(rightMapPoint.x - mapCenter.x)
        return Envelope(
            xRange: mapCenter.x - halfWidth ... mapCenter.x + halfWidth,
            yRange: mapCenter.y - halfWidth ... mapCenter.y + halfWidth,
            spatialReference: spatialReference
        )
    }
    
    /// Maps a pressed number key to a zero-based feature index.
    private func featureIndex(for characters: String) -> Int? {
        guard let lastCharacter = characters.last,
              let number = lastCharacter.wholeNumberValue,
              (1...9).contains(number) else {
            return nil
        }
        return number - 1
    }
    
    /// Shows the details callout for the selected numbered feature.
    private func showCalloutForFeature(at index: Int, mapViewProxy: MapViewProxy) {
        guard let feature = model.numberedFeatures[safe: index],
              let anchor = feature.geometry as? Point else {
            statusMessage = "No restaurant is assigned to \(index + 1)."
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
    
    /// A hidden text field that receives keyboard input and forwards number input.
    private func keyboardInputField(mapViewProxy: MapViewProxy) -> some View {
        KeyboardInputField(
            onNumber: { number in
                showCalloutForFeature(at: number - 1, mapViewProxy: mapViewProxy)
            },
            onEscape: dismissCallout
        )
            .frame(width: 1, height: 1)
            .opacity(0.01)
            .accessibilityHidden(true)
    }
    
    /// The instructions shown above the map.
    private var instructionsOverlay: some View {
        Text("Pan and zoom with the keyboard to bring restaurants into the rectangle. Press 1–9 for details, Esc to dismiss.")
            .font(.footnote)
            .multilineTextAlignment(.center)
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial, ignoresSafeAreaEdges: .horizontal)
    }
    
    /// The overflow message shown when more than nine features are selected.
    private var overflowMessage: some View {
        Text("More than nine restaurants are in the rectangle. Number keys identify the first nine, ordered top-to-bottom and left-to-right.")
            .font(.footnote)
            .multilineTextAlignment(.center)
            .padding(8)
            .background(.regularMaterial)
            .clipShape(.rect(cornerRadius: 8))
            .padding()
    }
    
    /// The status message shown when a number key has no matching restaurant.
    private var statusMessageOverlay: some View {
        Text(statusMessage)
            .font(.footnote)
            .multilineTextAlignment(.center)
            .padding(8)
            .background(.regularMaterial)
            .clipShape(.rect(cornerRadius: 8))
    }
    
    /// The callout content for a restaurant feature.
    private func calloutContent(for feature: Feature) -> some View {
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

private extension NavigateMapAndIdentifyFeaturesWithKeyboardView {
    /// A hidden UIKit text field that emits each typed digit as an event.
    struct KeyboardInputField: UIViewRepresentable {
        /// The action to perform when the user enters a number.
        var onNumber: (Int) -> Void
        
        /// The action to perform when the Escape key is pressed.
        var onEscape: () -> Void
        
        func makeUIView(context: Context) -> KeyboardTextField {
            let textField = KeyboardTextField()
            textField.delegate = context.coordinator
            textField.keyboardType = .numberPad
            textField.textContentType = .oneTimeCode
            textField.autocorrectionType = .no
            textField.tintColor = .clear
            textField.textColor = .clear
            textField.backgroundColor = .clear
            textField.onEscape = onEscape
            DispatchQueue.main.async {
                textField.becomeFirstResponder()
            }
            return textField
        }
        
        func updateUIView(_ textField: KeyboardTextField, context: Context) {
            context.coordinator.onNumber = onNumber
            textField.onEscape = onEscape
            if !textField.isFirstResponder {
                DispatchQueue.main.async {
                    textField.becomeFirstResponder()
                }
            }
        }
        
        func makeCoordinator() -> Coordinator {
            Coordinator(onNumber: onNumber)
        }
        
        /// The UIKit text field coordinator.
        final class Coordinator: NSObject, UITextFieldDelegate {
            /// The action to perform when the user enters a number.
            var onNumber: (Int) -> Void
            
            init(onNumber: @escaping (Int) -> Void) {
                self.onNumber = onNumber
            }
            
            func textField(
                _ textField: UITextField,
                shouldChangeCharactersIn range: NSRange,
                replacementString string: String
            ) -> Bool {
                for character in string {
                    guard let number = character.wholeNumberValue,
                          (1...9).contains(number) else { continue }
                    onNumber(number)
                }
                textField.text = ""
                return false
            }
        }
    }
    
    /// A text field that forwards hardware Escape key presses.
    final class KeyboardTextField: UITextField {
        /// The action to perform when the Escape key is pressed.
        var onEscape: (() -> Void)?
        
        override var keyCommands: [UIKeyCommand]? {
            return [
                UIKeyCommand(
                    input: UIKeyCommand.inputEscape,
                    modifierFlags: [],
                    action: #selector(handleEscapeKey)
                )
            ]
        }
        
        @objc
        private func handleEscapeKey() {
            onEscape?()
        }
    }
    
    /// The model for the sample.
    @MainActor
    @Observable
    final class Model {
        /// Attribute used to title and label each feature.
        private static let nameAttribute = "name"
        
        /// Colors used for the marker, selection halo, and label.
        private static let markerFillColor = UIColor(red: 11 / 255, green: 79 / 255, blue: 138 / 255, alpha: 1)
        static let selectionHaloColor = Color(red: 190 / 255, green: 24 / 255, blue: 93 / 255)
        private static let labelTextColor = UIColor(red: 31 / 255, green: 35 / 255, blue: 40 / 255, alpha: 1)
        
        /// The map displayed in the map view.
        let map: Map
        
        /// The feature table of restaurants in Redlands.
        let restaurantsTable = ServiceFeatureTable(url: .redlandsRestaurants)
        
        /// The feature layer holding the restaurants displayed and identified by the sample.
        let restaurantsLayer: FeatureLayer
        
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
                scale: 5_000
            )
            map.addOperationalLayer(restaurantsLayer)
            self.map = map
        }
        
        /// Selects, numbers, and labels restaurant features intersecting the given envelope.
        func selectFeatures(
            in envelope: Envelope?,
            screenPointForLocation: (Point) -> CGPoint?
        ) async throws {
            guard let envelope else { return }
            
            restaurantsLayer.clearSelection()
            labelOverlay.removeAllGraphics()
            numberedFeatures.removeAll()
            hasMoreThanNineSelectedFeatures = false
            
            let queryParameters = QueryParameters()
            queryParameters.geometry = envelope
            queryParameters.spatialRelationship = .intersects
            
            let queryResult = try await restaurantsTable.queryFeatures(using: queryParameters)
            let orderedFeatures = queryResult.features()
                .compactMap { feature -> OrderedFeature? in
                    guard let anchor = feature.geometry as? Point,
                          let screenPoint = screenPointForLocation(anchor) else {
                        return nil
                    }
                    return OrderedFeature(feature: feature, anchor: anchor, screenPoint: screenPoint)
                }
                .sorted { lhs, rhs in
                    lhs.screenPoint.y == rhs.screenPoint.y
                    ? lhs.screenPoint.x < rhs.screenPoint.x
                    : lhs.screenPoint.y < rhs.screenPoint.y
                }
            
            hasMoreThanNineSelectedFeatures = orderedFeatures.count > 9
            restaurantsLayer.selectFeatures(orderedFeatures.map(\.feature))
            
            for (offset, orderedFeature) in orderedFeatures.prefix(9).enumerated() {
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
        
        /// Reads the feature's name attribute, returning the fallback when it is missing or blank.
        func name(for feature: Feature, fallback: String?) -> String? {
            if let name = feature.attributes[Self.nameAttribute] as? String,
               !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return name
            } else {
                return fallback
            }
        }
        
        /// The restaurant marker symbol.
        private static var restaurantSymbol: SimpleMarkerSymbol {
            let symbol = SimpleMarkerSymbol(style: .circle, color: markerFillColor, size: 12)
            symbol.outline = SimpleLineSymbol(style: .solid, color: .white, width: 1.5)
            return symbol
        }
    }
    
    /// A feature and its screen-space ordering information.
    struct OrderedFeature {
        let feature: Feature
        let anchor: Point
        let screenPoint: CGPoint
    }
}

private extension Collection {
    /// Returns the element at the index if it exists.
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private extension URL {
    /// The URL of the Redlands restaurants feature service.
    static var redlandsRestaurants: URL {
        URL(string: "https://services2.arcgis.com/ZQgQTuoyBrtmoGdP/arcgis/rest/services/redlands_food/FeatureServer/0")!
    }
}

#Preview {
    NavigationStack {
        NavigateMapAndIdentifyFeaturesWithKeyboardView()
    }
}
