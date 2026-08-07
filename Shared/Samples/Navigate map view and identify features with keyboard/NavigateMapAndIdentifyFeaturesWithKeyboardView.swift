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
    /// Opens URLs using SwiftUI's environment-provided action.
    @Environment(\.openURL) private var openURL
    
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
    
    /// The size of the map view.
    @State private var mapSize: CGSize = .zero
    
    /// The error shown in the error alert.
    @State private var error: (any Error)?
    
    /// A Boolean value indicating whether the initial draw has completed.
    @State private var initialDrawCompleted = false
    
    /// The placement of the restaurant details callout.
    @State private var calloutPlacement: CalloutPlacement?
    
    /// The feature shown in the callout.
    @State private var calloutFeature: Feature?
    
    /// A Boolean value indicating whether the software keyboard input is active.
    @State private var isKeyboardInputActive = false
    
    /// The status message shown when a number key has no matching restaurant.
    @State private var statusMessage = ""
    
    /// The side length of the centered area-of-interest rectangle, in screen points.
    private var selectionRectangleLength: CGFloat { 360 }
    
    /// The selection halo color for selected restaurant features.
    private static let selectionHaloColor = Color(
        red: 190 / 255,
        green: 24 / 255,
        blue: 93 / 255
    )
    
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
        MapViewReader { mapView in
            MapView(map: map, graphicsOverlays: [model.labelOverlay])
                .selectionColor(Self.selectionHaloColor)
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
                    // Give the map view proxy time to settle before the first query.
                    try? await Task.sleep(for: .milliseconds(500))
                    await refreshSelection(mapSize: mapSize, mapView: mapView)
                }
                .task(id: isNavigating) {
                    if isNavigating {
                        await dismissCallout()
                    } else if initialDrawCompleted {
                        await refreshSelection(
                            mapSize: mapSize,
                            mapView: mapView
                        )
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
                        TipView(EnableKeyboardAccessTip()) { _ in
                            Task { await openAccessibilitySettings() }
                        }
                    }
                }
                .overlay(alignment: .bottom) {
                    VStack(spacing: 8) {
                        ZStack {
                            ForEach(1...9, id: \.self) { number in
                                Button("Select restaurant \(number)") {
                                    showCallout(forFeatureAtIndex: number - 1)
                                }
                                .keyboardShortcut(
                                    KeyEquivalent(Character(String(number))),
                                    modifiers: []
                                )
                            }
                        }
                        .frame(width: 0, height: 0)
                        .opacity(0)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)

                        if model.hasMoreThanNineSelectedFeatures {
                            Text("More than 9 restaurants are in the search area. Zoom in or pan to narrow the results.")
                                .statusText()
                        }
                        
                        if !statusMessage.isEmpty {
                            Text(statusMessage)
                                .statusText()
                        }
                    }
                    .padding(.bottom, 10)
                }
                .toolbar {
                    if !isFullKeyboardAccessEnabled {
                        ToolbarItem(placement: .bottomBar) {
                            Button("Show Keyboard") {
                                showKeyboard()
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
                .errorAlert(presentingError: $error)
        }
        .onGeometryChange(for: CGSize.self, of: \.size) { newMapSize in
            mapSize = newMapSize
        }
    }
    
    /// The selection rectangle's side length, clamped to fit within the map.
    private func rectangleLength(for mapSize: CGSize) -> CGFloat {
        min(selectionRectangleLength, mapSize.width, mapSize.height)
    }
    
    /// Refreshes the selected and numbered restaurant features for the current rectangle.
    private func refreshSelection(mapSize: CGSize, mapView: MapViewProxy) async {
        if let polygon = makeSelectionPolygon(mapSize: mapSize, mapView: mapView) {
            do {
                try await model.selectFeatures(
                    in: polygon,
                    pointConverter: { mapView.screenPoint(fromLocation: $0) }
                )
            } catch {
                self.error = error
            }
        } else {
            model.clearSelection()
        }
    }
    
    /// Makes a polygon matching the centered selection rectangle's map footprint.
    private func makeSelectionPolygon(mapSize: CGSize, mapView: MapViewProxy) -> ArcGIS.Polygon? {
        let halfLength = rectangleLength(for: mapSize) / 2
        let center = CGPoint(x: mapSize.width / 2, y: mapSize.height / 2)
        let screenCorners = [
            CGPoint(x: center.x - halfLength, y: center.y - halfLength),
            CGPoint(x: center.x + halfLength, y: center.y - halfLength),
            CGPoint(x: center.x + halfLength, y: center.y + halfLength),
            CGPoint(x: center.x - halfLength, y: center.y + halfLength)
        ]
        let mapCorners = screenCorners.compactMap(mapView.location(fromScreenPoint:))
        guard mapCorners.count == screenCorners.count else {
            return nil
        }
        
        return ArcGIS.Polygon(points: mapCorners)
    }
    
    /// Shows the details callout for the selected numbered feature.
    private func showCallout(forFeatureAtIndex index: Int) {
        if model.numberedFeatures.indices.contains(index),
           let anchor = model.numberedFeatures[index].geometry as? Point {
            let feature = model.numberedFeatures[index]
            statusMessage = ""
            calloutFeature = feature
            calloutPlacement = .geoElement(feature, tapLocation: anchor)
        } else {
            statusMessage = "No restaurant is assigned to \(index + 1)."
            calloutFeature = nil
            calloutPlacement = nil
        }
    }
    
    /// Dismisses the details callout and restores the selection rectangle.
    private func dismissCallout() async {
        calloutFeature = nil
        calloutPlacement = nil
        statusMessage = ""
    }

    /// Activates software keyboard input mode.
    private func showKeyboard() {
        isKeyboardInputActive = true
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
        openURL(.macOSAccessibilitySettings)
#else
        let candidates = [
            "App-prefs:ACCESSIBILITY",
            "App-prefs:root=ACCESSIBILITY",
            "prefs:root=ACCESSIBILITY"
        ]
        
        if let url = candidates.compactMap(URL.init).first(where: UIApplication.shared.canOpenURL) {
            openURL(url)
        } else {
            openURL(.appSettings)
        }
#endif
    }
}

private extension View {
    /// Styles a status message to float above the map.
    func statusText() -> some View {
        self
            .font(.footnote)
            .multilineTextAlignment(.center)
            .padding(8)
            .background(.regularMaterial)
            .clipShape(.rect(cornerRadius: 8))
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
