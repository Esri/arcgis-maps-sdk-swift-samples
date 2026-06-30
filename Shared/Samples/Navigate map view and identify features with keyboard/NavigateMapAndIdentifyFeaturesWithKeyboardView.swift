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

    /// The fraction of the map width used for each horizontal keyboard pan.
    private let horizontalPanStepRatio: CGFloat = 0.2

    /// The fraction of the map height used for each vertical keyboard pan.
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
                    .onKeyPress(.leftArrow) {
                        Task { await panHorizontally(direction: -1, mapSize: mapSize, mapViewProxy: mapViewProxy) }
                        return .handled
                    }
                    .onKeyPress(.rightArrow) {
                        Task { await panHorizontally(direction: 1, mapSize: mapSize, mapViewProxy: mapViewProxy) }
                        return .handled
                    }
                    .onKeyPress(.upArrow) {
                        Task { await panVertically(direction: -1, mapSize: mapSize, mapViewProxy: mapViewProxy) }
                        return .handled
                    }
                    .onKeyPress(.downArrow) {
                        Task { await panVertically(direction: 1, mapSize: mapSize, mapViewProxy: mapViewProxy) }
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
                        if !isKeyboardInputActive {
                            TipView(AreaOfInterestTip())
                        }
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
//                                TipView(KeyboardInputTip())
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
                    .overlay(alignment: .bottomTrailing) {
                        if !isKeyboardInputActive {
                            TipView(EnableKeyboardAccessTip())
                        }
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
        // Give SwiftUI time to add the TextField to the view hierarchy
        try? await Task.sleep(for: .milliseconds(200))
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
            .frame(height: 0)
            .opacity(0)
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

private struct KeyboardShortcutsOverlay: View {
    //    var show3DScene: Bool
    var onClose: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Spacer()
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .accessibilityLabel("Close Shortcuts")
                }
                .buttonStyle(.plain)
            }
            GroupBox(label: Text("Navigation").font(.headline)) {
                VStack(alignment: .leading, spacing: 8) {
                    ShortcutRow(icon: "arrow.up", description: "Pan Up")
                    ShortcutRow(icon: "arrow.down", description: "Pan Down")
                    ShortcutRow(icon: "arrow.left", description: "Pan Left")
                    ShortcutRow(icon: "arrow.right", description: "Pan Right")
                    //                    ShortcutRow(modifierIcon: show3DScene ? "command" : "option", icon: "arrow.up", description: "Zoom In")
                    //                    ShortcutRow(modifierIcon: show3DScene ? "command" : "option", icon: "arrow.down", description: "Zoom Out")
                    ShortcutRow(modifierIcon: "option", icon: "arrow.left", description: "Rotate Left")
                    ShortcutRow(modifierIcon: "option", icon: "arrow.right", description: "Rotate Right")
                }
            }
            GroupBox(label: Text("Identify Mode").font(.headline)) {
                VStack(alignment: .leading, spacing: 8) {
                    ShortcutRow(modifierIcon: "command", key: "I", description: "Identify Mode")
                    ShortcutRow(modifierIcon: "command", key: "1 - 7", description: "Select Feature (1 - 7)")
                    ShortcutRow(modifierIcon: "command", key: "8", description: "Previous Features")
                    ShortcutRow(modifierIcon: "command", key: "9", description: "Next Features")
                }
            }
            GroupBox(label: Text("Actions").font(.headline)) {
                ShortcutRow(modifierIcon: "command", key: "C", description: "Close Popup")
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 16, style: .continuous))
        .shadow(radius: 8)
        .frame(maxWidth: 380)
    }
}

private struct ShortcutRow: View {
    var modifierIcon: String? // e.g. "command", "option"
    var icon: String? // e.g. "arrow.up", "arrow.right"
    var key: String? // e.g. "I", "1", "2"
    var description: String
    
    var body: some View {
        HStack {
            HStack(spacing: 2) {
                if let modifierIcon {
                    Image(systemName: modifierIcon)
                        .font(.title3)
                }
                if let icon {
                    Image(systemName: icon)
                        .font(.title3)
                }
                if let key {
                    Text(key)
                        .font(.system(size: 17, design: .monospaced))
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
            }
            .accessibilityElement(children: .combine)
            Spacer()
            Text(description)
                .font(.body)
                .lineLimit(1)
        }
    }
}

private extension NavigateMapAndIdentifyFeaturesWithKeyboardView {
    /// A TipKit tip that explains the centered rectangle.
    struct AreaOfInterestTip: Tip {
        var title: Text {
            Text("Use the rectangle as the search area")
        }
        
        var message: Text? {
            Text(
                """
                 Use the arrow keys ← → ↑ ↓ on the keyboard to pan map. Pan until the restaurants you want to inspect are inside the rectangle. Press 1–9 on the keyboard to select a highlighted restaurant in the rectangle and view its details.
                 """
            )
        }
        
        var image: Image? {
            Image(systemName: "rectangle.dashed")
        }
    }
    
    struct EnableKeyboardAccessTip: Tip {
        /// The ID of the action that opens the Settings app.
        static let openSettingsActionID = "openSettings"
        
        var title: Text {
            Text("Enable Full Keyboard Access")
        }
        
        var message: Text? {
            Text(
                """
                To use a hardware keyboard with your mobile device you need to enable Full Keyboard Access.
                You can do this by opening the Settings app and navigating to:
                
                Accessibility > Keyboards & Typing.
                """
            )
        }
        
        var image: Image? {
            Image(systemName: "keyboard")
        }
        
        var actions: [Action] {
            Action(
                id: Self.openSettingsActionID,
                title: "Open Accessibility Settings"
            )
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
