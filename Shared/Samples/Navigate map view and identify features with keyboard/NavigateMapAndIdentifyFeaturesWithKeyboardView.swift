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
    
    /// The visible area of the map view.
    @State private var visibleArea: ArcGIS.Polygon?
    
    /// The current map scale.
    @State private var mapScale: Double = 0
    
    /// The current map rotation, in degrees.
    @State private var mapRotation = 0.0
    
    /// The side length of the centered area-of-interest rectangle, in screen points.
    private let selectionRectangleLength: CGFloat = 420
    
    /// The number keys that can identify features.
    private let featureNumberKeys = CharacterSet(charactersIn: "123456789")
    
    var body: some View {
        mapView
    }
    
    /// The main map view with all modifiers.
    @ViewBuilder private var mapView: some View {
        MapViewReader { mapViewProxy in
            GeometryReader { geometryProxy in
                let mapSize = geometryProxy.size
                let rectangleLength = min(selectionRectangleLength, min(mapSize.width, mapSize.height))
                
                MapView(map: model.map, graphicsOverlays: [model.labelOverlay])
                // Enable built-in keyboard navigation for pan, zoom, rotate, and reset north.
                    .interactionModes(.all)
                    .selectionColor(Model.selectionHaloColor)
                    .callout(placement: $calloutPlacement.animation(.default.speed(2))) { _ in
                        makeCalloutContent()
                    }
                    .onDrawStatusChanged { drawStatus in
                        handleDrawStatusChanged(drawStatus, mapSize: mapSize, mapViewProxy: mapViewProxy)
                    }
                    .onNavigatingChanged { navigating in
                        handleNavigatingChanged(navigating, mapSize: mapSize, mapViewProxy: mapViewProxy)
                    }
                    .onScaleChanged { mapScale = $0 }
                    .onVisibleAreaChanged { visibleArea = $0 }
                    .onRotationChanged { mapRotation = $0 }
                    .accessibilityLabel("Restaurant map")
                    .accessibilityHint("Use arrow keys to pan, plus and minus to zoom, Alt or Option with arrow keys to rotate or reset north, and number keys 1 through 9 to show restaurant details.")
                    .focusable()
                    .focused($mapHasFocus)
                    .onKeyPress(.escape) { () -> KeyPress.Result in
                        dismissCallout()
                        return .handled
                    }
                    .onKeyPress(characters: featureNumberKeys) { keyPress -> KeyPress.Result in
                        guard let featureIndex = featureIndex(for: keyPress.characters) else {
                            return .ignored
                        }
                        showCalloutForFeature(at: featureIndex)
                        return .handled
                    }
                    .ignoresSafeArea(SafeAreaRegions.keyboard, edges: Edge.Set.bottom)
                    .overlay(alignment: .center) {
                        makeSelectionRectangleOverlay(rectangleLength: rectangleLength)
                    }
                    .overlay(alignment: .top) {
                        TipView(AreaOfInterestTip())
                    }
                    .overlay(alignment: .bottom) {
                        makeBottomOverlayContent()
                    }
                    .overlay {
                        makeCatalystKeyboardShortcutBridge(mapSize: mapSize, mapViewProxy: mapViewProxy)
                    }
                    .toolbar {
                        ToolbarItem(placement: .bottomBar) {
                            Button("Show Keyboard") {
                                Task { await showKeyboard() }
                            }
                            .accessibilityLabel("Show restaurant number keyboard")
                        }
                    }
                    .onAppear {
                        // TipKit configuration is intended to happen once per process.
                        // Avoid showing an alert if this view appears multiple times.
                        try? Tips.configure([.displayFrequency(.immediate)])
                    }
                    .onDisappear {
                        refreshTask?.cancel()
                    }
                    .task {
                        await focusMap()
                    }
                    .errorAlert(presentingError: $error)
            }
        }
    }
    
    /// Creates the callout content.
    @ViewBuilder
    private func makeCalloutContent() -> some View {
        if let calloutFeature {
            let point = calloutFeature.geometry as? Point ?? Point(latitude: 0.0, longitude: 0.0)
            let featureTitle = model.name(for: calloutFeature, fallback: "Restaurant") ?? "Restaurant"
            calloutView(featureTitle: featureTitle, point: point)
        }
    }
    
    /// Creates the selection rectangle overlay.
    @ViewBuilder
    private func makeSelectionRectangleOverlay(rectangleLength: CGFloat) -> some View {
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
    
    /// Creates the bottom overlay content with tips and controls.
    @ViewBuilder
    private func makeBottomOverlayContent() -> some View {
        VStack(spacing: 8) {
            if model.hasMoreThanNineSelectedFeatures {
                Text("More than 9 restaurants are in the search area. Use Previous and Next to move between numbered groups, or zoom in or pan to narrow the results.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .padding(8)
                    .background(.regularMaterial)
                    .clipShape(.rect(cornerRadius: 8))
                makeFeatureGroupControls()
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
    
    /// Creates a Catalyst-specific keyboard shortcut bridge.
    @ViewBuilder
    private func makeCatalystKeyboardShortcutBridge(mapSize: CGSize, mapViewProxy: MapViewProxy) -> some View {
#if targetEnvironment(macCatalyst)
        CatalystKeyboardShortcutBridge { command in
            handleCatalystKeyboardShortcut(command, mapSize: mapSize, mapViewProxy: mapViewProxy)
        }
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
#endif
    }
    
    /// Handles draw status changes.
    private func handleDrawStatusChanged(_ drawStatus: DrawStatus, mapSize: CGSize, mapViewProxy: MapViewProxy) {
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
    
    /// Handles navigating state changes.
    private func handleNavigatingChanged(_ navigating: Bool, mapSize: CGSize, mapViewProxy: MapViewProxy) {
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
    
    /// Handles keyboard shortcuts delivered by the Catalyst keyboard bridge.
    private func handleCatalystKeyboardShortcut(_ command: CatalystKeyboardShortcutCommand, mapSize: CGSize, mapViewProxy: MapViewProxy) {
        switch command {
        case .dismissCallout:
            dismissCallout()
        case .showFeature(let index):
            showCalloutForFeature(at: index)
        case .pan(let xOffset, let yOffset):
            panMap(xOffset: xOffset, yOffset: yOffset, mapSize: mapSize, mapViewProxy: mapViewProxy)
        case .zoom(let factor):
            zoomMap(by: factor, mapViewProxy: mapViewProxy)
        case .rotate(let degrees):
            rotateMap(by: degrees, mapViewProxy: mapViewProxy)
        case .resetNorth:
            resetMapRotation(mapViewProxy: mapViewProxy)
        }
    }
    
    /// Pans the map by the given screen-point offsets.
    private func panMap(xOffset: CGFloat, yOffset: CGFloat, mapSize: CGSize, mapViewProxy: MapViewProxy) {
        let screenCenter = CGPoint(x: mapSize.width / 2, y: mapSize.height / 2)
        let targetScreenPoint = CGPoint(x: screenCenter.x + xOffset, y: screenCenter.y + yOffset)
        guard let targetCenter = mapViewProxy.location(fromScreenPoint: targetScreenPoint) else { return }
        
        Task {
            await mapViewProxy.setViewpointCenter(targetCenter, scale: mapScale)
        }
    }
    
    /// Zooms the map by multiplying the current scale by the given factor.
    private func zoomMap(by factor: Double, mapViewProxy: MapViewProxy) {
        guard let center = visibleArea?.extent.center, mapScale > 0 else { return }
        
        Task {
            await mapViewProxy.setViewpoint(Viewpoint(center: center, scale: mapScale * factor, rotation: mapRotation))
        }
    }
    
    /// Rotates the map by the given number of degrees.
    private func rotateMap(by degrees: Double, mapViewProxy: MapViewProxy) {
        setMapRotation(mapRotation + degrees, mapViewProxy: mapViewProxy)
    }
    
    /// Resets the map rotation to north.
    private func resetMapRotation(mapViewProxy: MapViewProxy) {
        setMapRotation(0, mapViewProxy: mapViewProxy)
    }
    
    /// Sets the map rotation to the given number of degrees.
    private func setMapRotation(_ rotation: Double, mapViewProxy: MapViewProxy) {
        guard let center = visibleArea?.extent.center, mapScale > 0 else { return }
        
        Task {
            await mapViewProxy.setViewpoint(Viewpoint(center: center, scale: mapScale, rotation: rotation))
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
    private func makeSelectionPolygon(mapSize: CGSize, mapViewProxy: MapViewProxy) -> ArcGIS.Polygon? {
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
    
    /// Shows the next group of numbered features.
    private func showNextFeatureGroup() {
        guard model.canShowNextFeatureGroup else { return }
        
        dismissCallout()
        model.nextGroupOfFeatures()
    }
    
    /// Shows the previous group of numbered features.
    private func showPreviousFeatureGroup() {
        guard model.canShowPreviousFeatureGroup else { return }
        
        dismissCallout()
        model.previousGroupOfFeatures()
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
            .accessibilityLabel("Restaurant number, 1 through 9")
            .accessibilityHint("Enter the number shown next to a restaurant to open its details.")
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
                            .accessibilityLabel("Done entering restaurant number")
                        }
                    }
                }
            }
    }
    
    /// Controls for navigating through groups of numbered features.
    private func makeFeatureGroupControls() -> some View {
        HStack(spacing: 12) {
            Button("Previous") {
                showPreviousFeatureGroup()
            }
            .disabled(!model.canShowPreviousFeatureGroup)
            .accessibilityLabel("Previous group of restaurants")
            .keyboardShortcut("[", modifiers: .command)
            
            Button("Next") {
                showNextFeatureGroup()
            }
            .disabled(!model.canShowNextFeatureGroup)
            .accessibilityLabel("Next group of restaurants")
            .keyboardShortcut("]", modifiers: .command)
        }
        .buttonStyle(.bordered)
        .font(.footnote)
    }
    
    private func calloutView(featureTitle: String, point: Point) -> some View {
        let latLong = point
            .formatted(.latitudeLongitude(style: .decimalDegrees, decimalPlaces: 2))
            .replacingOccurrences(of: " ", with: ", ")
        return VStack(alignment: .leading) {
            HStack {
                Text(featureTitle)
                    .font(.headline)
                    .accessibilityLabel("Restaurant, \(featureTitle)")
                Button("", systemImage: "xmark.circle.fill") {
                    dismissCallout()
                }
                .font(.title2)
                .accessibilityLabel("Close restaurant details")
                .keyboardShortcut("c")
            }
            Text("Location")
                .font(.headline)
            Text(latLong)
                .font(.callout)
                .accessibilityLabel("Location, \(latLong)")
        }
        .padding(5)
        .task {
            var highPriority = AttributedString("\(featureTitle), Location, \(latLong)")
            highPriority.accessibilitySpeechAnnouncementPriority = .high
            AccessibilityNotification.Announcement(highPriority).post()
        }
    }
}

private extension NavigateMapAndIdentifyFeaturesWithKeyboardView {
    /// A TipKit tip that explains the centered rectangle.
    struct AreaOfInterestTip: Tip {
        var title: Text {
            Text("Use the rectangle as the search area")
                .accessibilityLabel("Use the rectangle as the search area")
        }
        
        var message: Text? {
            Text("Pan and zoom the map until the restaurants you want to inspect are inside the rectangle. The current group is numbered from top-to-bottom and left-to-right.")
                .accessibilityLabel("Pan and zoom the map until the restaurants you want to inspect are inside the rectangle. The current group is numbered from top-to-bottom and left-to-right.")
        }
        
        var image: Image? {
            Image(systemName: "rectangle.dashed")
        }
    }
    
    /// A TipKit tip that explains keyboard input.
    struct KeyboardInputTip: Tip {
        var title: Text {
            Text("Use number keys for details")
                .accessibilityLabel("Use number keys for details")
        }
        
        var message: Text? {
            Text("Press 1–9 on a hardware keyboard, or use Show Keyboard to open the software keyboard. Use Done to dismiss it.")
                .accessibilityLabel("Press 1–9 on a hardware keyboard, or use Show Keyboard to open the software keyboard. Use Done to dismiss it.")
        }
    }
}

/// A keyboard shortcut command handled by the Catalyst keyboard bridge.
private enum CatalystKeyboardShortcutCommand {
    case dismissCallout
    case showFeature(Int)
    case pan(xOffset: CGFloat, yOffset: CGFloat)
    case zoom(factor: Double)
    case rotate(degrees: Double)
    case resetNorth
}

#if targetEnvironment(macCatalyst)
/// An invisible view that receives hardware keyboard commands in Mac Catalyst.
private struct CatalystKeyboardShortcutBridge: UIViewRepresentable {
    /// The action to perform when a keyboard shortcut is pressed.
    let action: (CatalystKeyboardShortcutCommand) -> Void
    
    func makeUIView(context: Context) -> KeyboardShortcutView {
        let view = KeyboardShortcutView()
        view.action = action
        DispatchQueue.main.async {
            view.becomeFirstResponder()
        }
        return view
    }
    
    func updateUIView(_ uiView: KeyboardShortcutView, context: Context) {
        uiView.action = action
        DispatchQueue.main.async {
            uiView.becomeFirstResponder()
        }
    }
    
    /// A view that can become first responder and vend `UIKeyCommand`s.
    final class KeyboardShortcutView: UIView {
        /// The distance to pan the map per arrow-key press, in screen points.
        private static let panOffset: CGFloat = 80
        
        /// The action to perform when a keyboard shortcut is pressed.
        var action: ((CatalystKeyboardShortcutCommand) -> Void)?
        
        override var canBecomeFirstResponder: Bool { true }
        
        override var keyCommands: [UIKeyCommand]? {
            let numberCommands = (1...9).map { number in
                UIKeyCommand(
                    input: "\(number)",
                    modifierFlags: [],
                    action: #selector(handleNumberKey(_:))
                )
            }
            
            return numberCommands + [
                UIKeyCommand(input: UIKeyCommand.inputEscape, modifierFlags: [], action: #selector(handleEscapeKey)),
                UIKeyCommand(input: UIKeyCommand.inputUpArrow, modifierFlags: [], action: #selector(handlePanUp)),
                UIKeyCommand(input: UIKeyCommand.inputDownArrow, modifierFlags: [], action: #selector(handlePanDown)),
                UIKeyCommand(input: UIKeyCommand.inputLeftArrow, modifierFlags: [], action: #selector(handlePanLeft)),
                UIKeyCommand(input: UIKeyCommand.inputRightArrow, modifierFlags: [], action: #selector(handlePanRight)),
                UIKeyCommand(input: "+", modifierFlags: [], action: #selector(handleZoomIn)),
                UIKeyCommand(input: "=", modifierFlags: [], action: #selector(handleZoomIn)),
                UIKeyCommand(input: "-", modifierFlags: [], action: #selector(handleZoomOut)),
                UIKeyCommand(input: UIKeyCommand.inputLeftArrow, modifierFlags: .alternate, action: #selector(handleRotateLeft)),
                UIKeyCommand(input: UIKeyCommand.inputRightArrow, modifierFlags: .alternate, action: #selector(handleRotateRight)),
                UIKeyCommand(input: UIKeyCommand.inputUpArrow, modifierFlags: .alternate, action: #selector(handleResetNorth))
            ]
        }
        
        @objc
        private func handleNumberKey(_ keyCommand: UIKeyCommand) {
            guard let input = keyCommand.input,
                  let number = Int(input),
                  (1...9).contains(number) else { return }
            action?(.showFeature(number - 1))
        }
        
        @objc
        private func handleEscapeKey() {
            action?(.dismissCallout)
        }
        
        @objc
        private func handlePanUp() {
            action?(.pan(xOffset: 0, yOffset: -Self.panOffset))
        }
        
        @objc private func handlePanDown() {
            action?(.pan(xOffset: 0, yOffset: Self.panOffset))
        }
        
        @objc private func handlePanLeft() {
            action?(.pan(xOffset: -Self.panOffset, yOffset: 0))
        }
        
        @objc private func handlePanRight() {
            action?(.pan(xOffset: Self.panOffset, yOffset: 0))
        }
        
        @objc private func handleZoomIn() {
            action?(.zoom(factor: 0.5))
        }
        
        @objc private func handleZoomOut() {
            action?(.zoom(factor: 2))
        }
        
        @objc private func handleRotateLeft() {
            action?(.rotate(degrees: -15))
        }
        
        @objc private func handleRotateRight() {
            action?(.rotate(degrees: 15))
        }
        
        @objc private func handleResetNorth() {
            action?(.resetNorth)
        }
    }
}
#endif

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
