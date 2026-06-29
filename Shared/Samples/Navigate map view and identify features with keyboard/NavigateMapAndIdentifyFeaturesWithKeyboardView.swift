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
    
    /// A task for delayed selection refresh after navigation ends.
    @State private var refreshTask: Task<Void, Never>?
    
    /// The side length of the centered area-of-interest rectangle, in screen points.
    private let selectionRectangleLength: CGFloat = 420
    
    /// The number keys that can identify features.
    private let featureNumberKeys = CharacterSet(charactersIn: "123456789")
    
    var body: some View {
        MapViewReader { mapViewProxy in
            GeometryReader { geometryProxy in
                let mapSize = geometryProxy.size
                let rectangleLength = min(selectionRectangleLength, min(mapSize.width, mapSize.height))
                
                MapView(map: model.map, graphicsOverlays: [model.labelOverlay])
                    .interactionModes([.pan, .zoom])
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
// Ensure the feature table is fully loaded before querying.
try await model.ensureTableLoaded()
                                
                                // Additional delay to ensure map view proxy is fully ready and settled
                                try? await Task.sleep(for: .milliseconds(500))
                                await refreshSelection(mapSize: mapSize, mapViewProxy: mapViewProxy)
                                await focusMap()
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
                            if isKeyboardInputActive {
                                TipView(KeyboardInputTip())
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
                    .onAppear {
                        // TipKit configuration is intended to happen once per process.
                        // Avoid showing an alert if this view appears multiple times.
                        try? Tips.configure([.displayFrequency(.immediate)])
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
            let selectionRectangle = makeSelectionRectangle(mapSize: mapSize)
            try await model.selectFeatures(
                intersecting: makeSelectionPolygon(mapSize: mapSize, mapViewProxy: mapViewProxy),
                containsScreenPoint: selectionRectangle.contains,
                screenPointFor: { mapViewProxy.screenPoint(fromLocation: $0) }
            )
        } catch {
            self.error = error
        }
    }
    
    /// Makes the centered selection rectangle in screen coordinates.
    private func makeSelectionRectangle(mapSize: CGSize) -> CGRect {
        let clampedRectangleLength = min(selectionRectangleLength, min(mapSize.width, mapSize.height))
        let screenCenter = CGPoint(x: mapSize.width / 2, y: mapSize.height / 2)
        let halfLength = clampedRectangleLength / 2
        
        return CGRect(
            x: screenCenter.x - halfLength,
            y: screenCenter.y - halfLength,
            width: clampedRectangleLength,
            height: clampedRectangleLength
        )
    }
    
    /// Makes a polygon matching the centered selection rectangle's map footprint.
    private func makeSelectionPolygon(mapSize: CGSize, mapViewProxy: MapViewProxy) -> Polygon? {
        let selectionRectangle = makeSelectionRectangle(mapSize: mapSize)
        let screenCenter = CGPoint(x: selectionRectangle.midX, y: selectionRectangle.midY)
        let halfLength = selectionRectangle.width / 2
        
        // Sample all four corners so the query geometry matches the rotated screen rectangle.
        let topLeft = CGPoint(x: screenCenter.x - halfLength, y: screenCenter.y - halfLength)
        let topRight = CGPoint(x: screenCenter.x + halfLength, y: screenCenter.y - halfLength)
        let bottomRight = CGPoint(x: screenCenter.x + halfLength, y: screenCenter.y + halfLength)
        let bottomLeft = CGPoint(x: screenCenter.x - halfLength, y: screenCenter.y + halfLength)
        
        // Convert all corners to map coordinates.
        let corners = [topLeft, topRight, bottomRight, bottomLeft]
        let mapPoints = corners.compactMap { mapViewProxy.location(fromScreenPoint: $0) }

        // Ensure we got all 4 corners converted
        guard mapPoints.count == 4,
              let spatialReference = mapPoints.first?.spatialReference else {
            return nil
        }
        
        let polygonBuilder = PolygonBuilder(spatialReference: spatialReference)
        for point in mapPoints {
            polygonBuilder.add(point)
        }
        return polygonBuilder.toGeometry()
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

    if isKeyboardInputActive {
        keyboardInputHasFocus = true
    } else {
        Task { await focusMap() }
    }
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
                    VStack {
                        HStack {
                            Spacer()
                            Button("Done") {
                                hideKeyboard()
                            }
                        }
                    }
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
