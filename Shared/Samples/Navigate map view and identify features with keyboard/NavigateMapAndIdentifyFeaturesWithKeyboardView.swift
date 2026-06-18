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

struct NavigateMapAndIdentifyFeaturesWithKeyboardView: View {
    /// Configures TipKit for this sample.
    private static let tipConfiguration: Void = {
        #if DEBUG
        try? Tips.resetDatastore()
        #endif
        try? Tips.configure([.displayFrequency(.immediate)])
    }()

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
    
    /// A Boolean value indicating whether the map has keyboard focus.
    @FocusState private var mapHasFocus: Bool
    
    /// A Boolean value indicating whether the software keyboard input is active.
    @State private var isKeyboardInputActive = false
    
    /// The text used to receive software keyboard input.
    @State private var keyboardInput = ""
    
    /// A Boolean value indicating whether the keyboard input field has focus.
    @FocusState private var keyboardInputHasFocus: Bool
    
    /// The status message shown when a number key has no matching restaurant.
    @State private var statusMessage = ""
    
    /// The side length of the centered area-of-interest rectangle, in screen points.
    private let selectionRectangleLength: CGFloat = 420
    
    /// The number keys that can identify features.
    private let featureNumberKeys = CharacterSet(charactersIn: "123456789")

    /// A tip explaining the area of interest rectangle.
    private let areaOfInterestTip = AreaOfInterestTip()

    /// A tip explaining how to show and use the software keyboard.
    private let keyboardInputTip = KeyboardInputTip()

    init() {
        _ = Self.tipConfiguration
    }
    
    var body: some View {
        MapViewReader { mapViewProxy in
            GeometryReader { geometryProxy in
                let mapSize = geometryProxy.size
                
                MapView(map: model.map, graphicsOverlays: [model.labelOverlay])
                    .selectionColor(Model.selectionHaloColor)
                    .callout(placement: $calloutPlacement.animation(.default.speed(2))) { _ in
                        if let calloutFeature {
                            makeCalloutContent(feature: calloutFeature)
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
                        await focusMap()
                    }
                    .task(id: isNavigating) {
                        guard !isNavigating, initialDrawCompleted else { return }
                        await refreshSelection(mapSize: mapSize, mapViewProxy: mapViewProxy)
                    }
                    .focusable()
                    .focused($mapHasFocus)
                    .onKeyPress(.escape) {
                        dismissCallout()
                        return .handled
                    }
                    .onKeyPress(characters: featureNumberKeys) { keyPress in
                        guard let featureIndex = featureIndex(for: keyPress.characters) else {
                            return .ignored
                        }
                        showCalloutForFeature(at: featureIndex)
                        return .handled
                    }
                    .ignoresSafeArea(.keyboard, edges: .bottom)
                    .overlay(alignment: .center) {
                        if calloutPlacement == nil {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.pink.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(.pink, lineWidth: 2)
                                )
                                .frame(width: min(selectionRectangleLength, min(mapSize.width, mapSize.height)), height: min(selectionRectangleLength, min(mapSize.width, mapSize.height)))
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
                                Text("More than 9 restaurants are in the search area. Zoom in or pan to narrow the results.")
                                    .font(.footnote)
                                    .multilineTextAlignment(.center)
                                    .padding(8)
                                    .background(.regularMaterial)
                                    .clipShape(.rect(cornerRadius: 8))
                            }
                            if !statusMessage.isEmpty {
                                statusMessageOverlay
                            }
                            TipView(keyboardInputTip)
                            if isKeyboardInputActive {
                                makeKeyboardInputBar()
                            }
                        }
                        .padding(.bottom)
                    }
                    .toolbar {
                        ToolbarItem(placement: .bottomBar) {
                            Button("Show Keyboard") {
                                Task { await showKeyboard() }
                            }
                        }
                    }
                    .task {
                        await focusMap()
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
        let rightScreenPoint = CGPoint(
            x: screenCenter.x + clampedRectangleLength / 2,
            y: screenCenter.y
        )
        let topScreenPoint = CGPoint(
            x: screenCenter.x,
            y: screenCenter.y - clampedRectangleLength / 2
        )
        
        guard let mapCenter = mapViewProxy.location(fromScreenPoint: screenCenter),
              let rightMapPoint = mapViewProxy.location(fromScreenPoint: rightScreenPoint),
              let topMapPoint = mapViewProxy.location(fromScreenPoint: topScreenPoint),
              let spatialReference = mapCenter.spatialReference else {
            return nil
        }
        
        let halfWidth = abs(rightMapPoint.x - mapCenter.x)
        let halfHeight = abs(topMapPoint.y - mapCenter.y)
        return Envelope(
            xRange: mapCenter.x - halfWidth ... mapCenter.x + halfWidth,
            yRange: mapCenter.y - halfHeight ... mapCenter.y + halfHeight,
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
        if isKeyboardInputActive {
            keyboardInputHasFocus = true
        } else {
            Task { await focusMap() }
        }
    }
    
    /// Dismisses the details callout and restores the selection rectangle.
    private func dismissCallout() {
        calloutFeature = nil
        calloutPlacement = nil
        statusMessage = ""
        Task { await focusMap() }
    }
    
    /// Gives keyboard focus to the map after SwiftUI finishes the current update.
    @MainActor
    private func focusMap() async {
        mapHasFocus = false
        await Task.yield()
        try? await Task.sleep(for: .milliseconds(100))
        mapHasFocus = true
    }
    
    /// Shows the software keyboard by focusing the hidden number input field.
    @MainActor
    private func showKeyboard() async {
        isKeyboardInputActive = true
        mapHasFocus = false
        keyboardInputHasFocus = false
        await Task.yield()
        try? await Task.sleep(for: .milliseconds(100))
        keyboardInputHasFocus = true
    }
    
    /// Hides the software keyboard input bar and returns focus to the map.
    private func hideKeyboard() {
        keyboardInput = ""
        keyboardInputHasFocus = false
        isKeyboardInputActive = false
        dismissCallout()
    }
    
    /// A hidden text field used to receive software keyboard input.
    private func makeKeyboardInputBar() -> some View {
        TextField("1–9", text: $keyboardInput)
            .keyboardType(.numberPad)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($keyboardInputHasFocus)
            .frame(width: 1, height: 1)
            .opacity(0.01)
            .accessibilityLabel("Restaurant number")
            .onChange(of: keyboardInput) { _, newValue in
                guard let featureIndex = featureIndex(for: newValue) else {
                    keyboardInput = ""
                    return
                }
                keyboardInput = ""
                showCalloutForFeature(at: featureIndex)
                keyboardInputHasFocus = true
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        hideKeyboard()
                    }
                }
            }
    }
    
    /// The instructions shown above the map.
    private var instructionsOverlay: some View {
        TipView(areaOfInterestTip)
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

private extension NavigateMapAndIdentifyFeaturesWithKeyboardView {
    /// A TipKit tip that explains the centered rectangle.
    struct AreaOfInterestTip: Tip {
        var title: Text {
            Text("Use the rectangle as the search area")
        }

        var message: Text? {
            Text("Pan and zoom the map until the restaurants you want to inspect are inside the rectangle. The first nine are numbered from top-to-bottom and left-to-right.")
        }

        var image: Image? {
            Image(systemName: "rectangle.dashed")
        }
    }

    /// A TipKit tip that explains keyboard input.
    struct KeyboardInputTip: Tip {
        var title: Text {
            Text("Use number keys for details")
        }

        var message: Text? {
            Text("Press 1–9 on a hardware keyboard, or use Show Keyboard to open the software keyboard. Use Done to dismiss it.")
        }

        var image: Image? {
            Image(systemName: "keyboard")
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
        NavigateMapAndIdentifyFeaturesWithKeyboardView()
    }
}
