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
import UIKit

struct NavigateMapAndIdentifyFeaturesWithKeyboardView: View {
    /// The current scene phase of the sample.
    @Environment(\.scenePhase) private var scenePhase
    
    /// The view model for the sample.
    @State private var model = Model()
    
    /// The map displayed in the map view.
    @State private var map: Map = {
        let map = Map(basemapStyle: .arcGISLightGray)
        map.initialViewpoint = Viewpoint(
            center: Point(
                x: -117.1825,
                y: 34.0556,
                spatialReference: .wgs84
            ),
            scale: 4_000
        )
        return map
    }()
    
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
    
    /// A task for the delayed selection refresh after navigation ends.
    @State private var refreshTask: Task<Void, Never>?
    
    /// A token used to reactivate the UIKit key-command responder.
    @State private var keyboardCommandCaptureActivation = 0
    
    /// The side length of the centered area-of-interest rectangle, in screen points.
    private var selectionRectangleLength: CGFloat { 360 }
    
    /// The number keys that can identify features.
    private let featureNumberKeys = CharacterSet(charactersIn: "123456789")
    
    /// The fraction of the map size used for each keyboard pan step.
    private var panStepRatio: CGFloat { 0.2 }
    
    /// A tip explaining how to enable Full Keyboard Access.
    private let enableKeyboardAccessTip = EnableKeyboardAccessTip()
    
    @State private var isNavigating: Bool = false
    
    private var isFullKeyboardAccessEnabled: Bool {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first else {
            return false
        }
        // On iPhone, a focus system exists only when Full Keyboard Access is on.
        // Caveat: on iPad, a connected hardware keyboard alone creates a focus
        // system, so this reads as a false positive there.
        return UIFocusSystem.focusSystem(for: window) != nil
    }
    
    var body: some View {
        MapViewReader { mapViewProxy in
            GeometryReader { geometryProxy in
                let mapSize = geometryProxy.size
                
                MapView(map: map, graphicsOverlays: [model.labelOverlay])
                    .selectionColor(Model.selectionHaloColor)
                    .callout(placement: $calloutPlacement.animation(.default.speed(2))) { _ in
                        if let calloutFeature {
                            calloutContent(for: calloutFeature)
                        }
                    }
                    .onNavigatingChanged { newIsNavigating in
                        isNavigating = newIsNavigating
                    }
                    .onDrawStatusChanged { newDrawStatus in
                        guard newDrawStatus == .completed, !initialDrawCompleted else { return }
                        initialDrawCompleted = true
                    }
                    .task(id: initialDrawCompleted) {
                        guard initialDrawCompleted else { return }
                        do {
                            // Give the map view proxy time to settle before the first query.
                            try? await Task.sleep(for: .milliseconds(500))
                            await refreshSelection(mapSize: mapSize, mapViewProxy: mapViewProxy)
                            await focusMap()
                        } catch is CancellationError {
                            // Do nothing.
                        } catch {
                            self.error = error
                        }
                    }
                    .task(id: isNavigating) {
                        if isNavigating {
                            await dismissCallout()
                        } else if initialDrawCompleted {
                            await refreshSelection(
                                mapSize: mapSize,
                                mapViewProxy: mapViewProxy
                            )
                        }
                    }
                    .focusable()
                    .focused($mapHasFocus)
                    .onKeyPress(.escape) {
                        Task { await dismissCallout() }
                        return .handled
                    }
                    .onKeyPress(keys: [.leftArrow, .rightArrow, .upArrow, .downArrow]) { keyPress in
                        let direction: CGVector = switch keyPress.key {
                        case .leftArrow: CGVector(dx: -1, dy: 0)
                        case .rightArrow: CGVector(dx: 1, dy: 0)
                        case .upArrow: CGVector(dx: 0, dy: -1)
                        default: CGVector(dx: 0, dy: 1)
                        }
                        Task {
                            await pan(toward: direction, mapSize: mapSize, mapViewProxy: mapViewProxy)
                        }
                        return .handled
                    }
                    .onKeyPress(characters: featureNumberKeys) { keyPress in
                        guard let featureIndex = featureIndex(for: keyPress.characters) else {
                            return .ignored
                        }
                        showCallout(forFeatureAtIndex: featureIndex)
                        return .handled
                    }
                    .overlay {
                        if isFullKeyboardAccessEnabled && !isKeyboardInputActive {
                            // Capture key commands through UIKit first responder when FKA reroutes SwiftUI focus.
                            KeyboardCommandCaptureView(
                                activationToken: keyboardCommandCaptureActivation,
                                onPan: { direction in
                                    Task {
                                        await pan(toward: direction, mapSize: mapSize, mapViewProxy: mapViewProxy)
                                    }
                                },
                                onEscape: {
                                    Task { await dismissCallout() }
                                },
                                onNumber: { featureIndex in
                                    showCallout(forFeatureAtIndex: featureIndex)
                                }
                            )
                            .frame(width: 1, height: 1)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                        }
                    }
                    .ignoresSafeArea(.keyboard, edges: .bottom)
                    .overlay(alignment: .center) {
                        if calloutPlacement == nil {
                            let rectangleLength = self.rectangleLength(for: mapSize)
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
                    .overlay(alignment: .bottomTrailing) {
                        if !isFullKeyboardAccessEnabled && !isKeyboardInputActive {
                            TipView(enableKeyboardAccessTip) { _ in
                                Task { await openAccessibilitySettings() }
                            }
                        }
                    }
                    .overlay(alignment: .bottom) {
                        VStack(spacing: 8) {
                            if model.hasMoreThanNineSelectedFeatures {
                                statusText("More than 9 restaurants are in the search area. Zoom in or pan to narrow the results.")
                            }
                            if !statusMessage.isEmpty {
                                statusText(statusMessage)
                            }
                            if isKeyboardInputActive {
                                keyboardInputBar
                            }
                        }
                        .padding(.bottom, 10)
                    }
                    .toolbar {
                        if !isFullKeyboardAccessEnabled {
                            ToolbarItem(placement: .bottomBar) {
                                Button("Show Keyboard") {
                                    Task { await showKeyboard() }
                                }
                            }
                        }
                    }
                    .onAppear {
                        // TipKit configuration is intended to happen once per process.
                        try? Tips.configure([.displayFrequency(.immediate)])

                        guard map.operationalLayers.isEmpty else { return }
                        map.addOperationalLayer(model.restaurantsLayer)
                    }
                    .task {
                        await focusMap()
                    }
                    .task(id: scenePhase) {
                        guard scenePhase == .active else { return }
                        await focusMap()
                    }
                    .errorAlert(presentingError: $error)
            }
        }
    }
    
    /// The selection rectangle's side length, clamped to fit within the map.
    private func rectangleLength(for mapSize: CGSize) -> CGFloat {
        min(selectionRectangleLength, mapSize.width, mapSize.height)
    }
    
    /// Refreshes the selected and numbered restaurant features for the current rectangle.
    @MainActor
    private func refreshSelection(mapSize: CGSize, mapViewProxy: MapViewProxy) async {
        if let polygon = makeSelectionPolygon(mapSize: mapSize, mapViewProxy: mapViewProxy) {
            do {
                try await model.selectFeatures(
                    in: polygon,
                    pointConverter: { mapViewProxy.screenPoint(fromLocation: $0) }
                )
            } catch {
                self.error = error
            }
        } else {
            model.clearSelection()
        }
    }
    
    /// Makes a polygon matching the centered selection rectangle's map footprint.
    private func makeSelectionPolygon(mapSize: CGSize, mapViewProxy: MapViewProxy) -> ArcGIS.Polygon? {
        let halfLength = rectangleLength(for: mapSize) / 2
        let center = CGPoint(x: mapSize.width / 2, y: mapSize.height / 2)
        let screenCorners = [
            CGPoint(x: center.x - halfLength, y: center.y - halfLength),
            CGPoint(x: center.x + halfLength, y: center.y - halfLength),
            CGPoint(x: center.x + halfLength, y: center.y + halfLength),
            CGPoint(x: center.x - halfLength, y: center.y + halfLength)
        ]
        let mapCorners = screenCorners.compactMap(mapViewProxy.location(fromScreenPoint:))
        guard mapCorners.count == screenCorners.count else {
            return nil
        }
        
        return ArcGIS.Polygon(points: mapCorners)
    }
    
    /// Pans the map by shifting the center a fraction of the map size in a screen-space direction.
    /// - Parameters:
    ///   - direction: The unit direction to pan toward, in screen space.
    ///   - mapSize: The size of the map view.
    ///   - mapViewProxy: The proxy used to update the viewpoint.
    @MainActor
    private func pan(toward direction: CGVector, mapSize: CGSize, mapViewProxy: MapViewProxy) async {
        await dismissCallout()
        
        let targetScreenPoint = CGPoint(
            x: mapSize.width / 2 + mapSize.width * panStepRatio * direction.dx,
            y: mapSize.height / 2 + mapSize.height * panStepRatio * direction.dy
        )
        
        guard let targetCenter = mapViewProxy.location(fromScreenPoint: targetScreenPoint) else {
            return
        }
        await mapViewProxy.setViewpointCenter(targetCenter)
        await focusMap()
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
    private func showCallout(forFeatureAtIndex index: Int) {
        if model.numberedFeatures.indices.contains(index),
           let anchor = model.numberedFeatures[index].geometry as? Point {
            let feature = model.numberedFeatures[index]
            statusMessage = ""
            calloutFeature = feature
            calloutPlacement = .geoElement(feature, tapLocation: anchor)
            if isKeyboardInputActive {
                keyboardInputHasFocus = true
            } else {
                Task { await focusMap() }
            }
        } else {
            statusMessage = "No restaurant is assigned to \(index + 1)."
            calloutFeature = nil
            calloutPlacement = nil
        }
    }
    
    /// Dismisses the details callout and restores the selection rectangle.
    @MainActor
    private func dismissCallout() async {
        calloutFeature = nil
        calloutPlacement = nil
        statusMessage = ""
        await focusMap()
    }
    
    /// Gives keyboard focus to the map after SwiftUI finishes the current update.
    @MainActor
    private func focusMap() async {
        guard !isFullKeyboardAccessEnabled else {
            keyboardCommandCaptureActivation += 1
            return
        }
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
        // Give SwiftUI time to add the text field to the view hierarchy.
        try? await Task.sleep(for: .milliseconds(200))
        keyboardInputHasFocus = true
    }
    
    /// Hides the software keyboard input bar and returns focus to the map.
    @MainActor
    private func hideKeyboard() async {
        keyboardInput = ""
        keyboardInputHasFocus = false
        isKeyboardInputActive = false
        await dismissCallout()
    }
    
    /// A status message styled to float above the map.
    private func statusText(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .multilineTextAlignment(.center)
            .padding(8)
            .background(.regularMaterial)
            .clipShape(.rect(cornerRadius: 8))
    }
    
    /// A hidden text field used to receive software keyboard input.
    private var keyboardInputBar: some View {
        TextField("1–9", text: $keyboardInput)
            .keyboardType(.numberPad)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($keyboardInputHasFocus)
            .frame(height: 0)
            .opacity(0)
            .accessibilityLabel("Restaurant number")
            .onChange(of: keyboardInput) { _, newValue in
                keyboardInput = ""
                guard let featureIndex = featureIndex(for: newValue) else { return }
                showCallout(forFeatureAtIndex: featureIndex)
                keyboardInputHasFocus = true
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        Task { await hideKeyboard() }
                    }
                }
            }
    }
    
    /// The callout content for a restaurant feature.
    private func calloutContent(for feature: Feature) -> some View {
        let anchor = feature.geometry as? Point
        let wgs84Point = anchor.flatMap { GeometryEngine.project($0, into: .wgs84) }
        
        return VStack(alignment: .leading) {
            Text(model.name(for: feature) ?? "Restaurant")
                .font(.headline)
            if let wgs84Point {
                Text("Lat: \(wgs84Point.y, format: .number.precision(.fractionLength(6)))")
                Text("Lon: \(wgs84Point.x, format: .number.precision(.fractionLength(6)))")
            }
        }
        .padding(5)
    }
    
    /// Opens the Settings app to an Accessibility feature when supported.
    private func openAccessibilitySettings() async {
        do {
            if #available(iOS 26.0, *) {
                try await AccessibilitySettings.openSettings(for: .assistiveTouchDevices)
            } else {
                openLegacyAccessibilitySettings()
            }
        } catch {
            openLegacyAccessibilitySettings()
        }
    }
    
    /// Attempts to open the Accessibility menu on older iOS versions.
    /// Falls back to this app's settings page when direct links are unavailable.
    private func openLegacyAccessibilitySettings() {
#if targetEnvironment(macCatalyst)
        UIApplication.shared.open(.macOSAccessibilitySettings)
#else
        let candidates = [
            "App-prefs:ACCESSIBILITY",
            "App-prefs:root=ACCESSIBILITY",
            "prefs:root=ACCESSIBILITY"
        ]
        
        if let url = candidates.compactMap(URL.init).first(where: UIApplication.shared.canOpenURL) {
            UIApplication.shared.open(url)
        } else {
            UIApplication.shared.open(.appSettings)
        }
#endif
    }
}

private extension URL {
    /// The URL of this app's page in the Settings app.
    static var appSettings: URL {
        URL(string: UIApplication.openSettingsURLString)!
    }
}

#Preview {
    NavigationStack {
        NavigateMapAndIdentifyFeaturesWithKeyboardView()
    }
}

private struct KeyboardCommandCaptureView: UIViewRepresentable {
    let activationToken: Int
    let onPan: (CGVector) -> Void
    let onEscape: () -> Void
    let onNumber: (Int) -> Void
    
    func makeUIView(context: Context) -> ResponderView {
        let view = ResponderView()
        view.backgroundColor = .clear
        return view
    }
    
    func updateUIView(_ uiView: ResponderView, context: Context) {
        uiView.onPan = onPan
        uiView.onEscape = onEscape
        uiView.onNumber = onNumber
        uiView.activateIfNeeded()
    }
}

private extension KeyboardCommandCaptureView {
    final class ResponderView: UIView {
        var onPan: ((CGVector) -> Void)?
        var onEscape: (() -> Void)?
        var onNumber: ((Int) -> Void)?
        
        override var canBecomeFirstResponder: Bool { true }
        
        override var keyCommands: [UIKeyCommand]? {
            let arrowInputs = [
                UIKeyCommand.inputLeftArrow,
                UIKeyCommand.inputRightArrow,
                UIKeyCommand.inputUpArrow,
                UIKeyCommand.inputDownArrow
            ]
            let arrowCommands = arrowInputs.flatMap { input in
                [
                    UIKeyCommand(input: input, modifierFlags: [], action: #selector(handleKeyCommand(_:))),
                    UIKeyCommand(input: input, modifierFlags: .shift, action: #selector(handleKeyCommand(_:)))
                ]
            }
            var commands = arrowCommands + [
                UIKeyCommand(input: UIKeyCommand.inputEscape, modifierFlags: [], action: #selector(handleKeyCommand(_:)))
            ]
            commands.append(contentsOf: (1...9).map {
                UIKeyCommand(input: "\($0)", modifierFlags: [], action: #selector(handleKeyCommand(_:)))
            })
            return commands
        }
        
        override func didMoveToWindow() {
            super.didMoveToWindow()
            activateIfNeeded()
        }
        
        func activateIfNeeded() {
            guard window != nil else { return }
            DispatchQueue.main.async { [weak self] in
                _ = self?.becomeFirstResponder()
            }
        }
        
        @objc
        private func handleKeyCommand(_ command: UIKeyCommand) {
            guard let input = command.input else { return }
            switch input {
            case UIKeyCommand.inputLeftArrow:
                onPan?(CGVector(dx: -1, dy: 0))
            case UIKeyCommand.inputRightArrow:
                onPan?(CGVector(dx: 1, dy: 0))
            case UIKeyCommand.inputUpArrow:
                onPan?(CGVector(dx: 0, dy: -1))
            case UIKeyCommand.inputDownArrow:
                onPan?(CGVector(dx: 0, dy: 1))
            case UIKeyCommand.inputEscape:
                onEscape?()
            default:
                guard let number = Int(input), (1...9).contains(number) else { return }
                onNumber?(number - 1)
            }
        }
    }
}
