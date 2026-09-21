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

struct UpdateLabelsAndSymbolsToScaleForVisualAccessibilityView: View {
    /// The view model for the sample.
    @State private var model = Model()
    
    /// The error shown in an alert, if any.
    @State private var error: (any Error)?
    
    /// Opens the platform's accessibility settings.
    @Environment(\.openURL) private var openURL
    
    /// Instructions for changing the system text size.
    private let textSizeTip = TextSizeTip()
    
    /// The screen point to identify, if any.
    @State private var identifyPoint: CGPoint?
    
    /// The selected restaurant and its callout placement.
    @State private var selectedFeature: Feature?
    @State private var calloutPlacement: CalloutPlacement?
    
    /// A scale factor relative to the default body text size.
    @ScaledMetric(relativeTo: .body) private var systemTextScale: CGFloat = 1
    
    var body: some View {
        @Bindable var model = model
        
        MapViewReader { mapViewProxy in
            MapView(map: model.map)
                .callout(placement: $calloutPlacement) { _ in
                    if let selectedFeature {
                        calloutContent(for: selectedFeature)
                    }
                }
                .onSingleTapGesture { screenPoint, _ in
                    model.restaurantsLayer.clearSelection()
                    selectedFeature = nil
                    calloutPlacement = nil
                    identifyPoint = screenPoint
                }
                .task(id: identifyPoint) {
                    guard let identifyPoint else { return }
                    do {
                        // Identify at most one restaurant near the tap.
                        let result = try await mapViewProxy.identify(
                            on: model.restaurantsLayer,
                            screenPoint: identifyPoint,
                            tolerance: 12,
                            maximumResults: 1
                        )
                        // Don't show stale results after another tap
                        // or dismissal.
                        try Task.checkCancellation()
                        guard
                            let feature = result.geoElements.first as? Feature,
                            let location = feature.geometry as? Point
                        else { return }
                        model.restaurantsLayer.selectFeature(feature)
                        selectedFeature = feature
                        calloutPlacement = .geoElement(
                            feature,
                            tapLocation: location
                        )
                    } catch {
                        if !Task.isCancelled {
                            self.error = error
                        }
                    }
                }
                .task {
                    do {
                        try await model.restaurantsLayer.load()
                    } catch {
                        if !Task.isCancelled {
                            self.error = error
                        }
                    }
                }
                .onChange(of: systemTextScale, initial: true) { _, newValue in
                    model.applySystemTextScale(newValue)
                }
                .onAppear {
                    // Configure TipKit once per process. Ignore errors if
                    // another sample has already configured it.
                    try? Tips.configure([.displayFrequency(.immediate)])
                }
                .overlay(alignment: .top) {
                    TipView(textSizeTip) { action in
                        if action.id == TextSizeTip.openSettingsActionID {
                            openAccessibilitySettings()
                        }
                    }
                    .padding()
                }
                .overlay(alignment: .bottom) {
                    scalingStatus
                }
                .toolbar {
                    ToolbarItem(placement: .bottomBar) {
                        Toggle(
                            "Scale Labels",
                            isOn: $model.labelsUseSystemTextScale
                        )
                        .toggleStyle(.switch)
                        .accessibilityHint(
                            """
                            Apply system text size to restaurant labels. \
                            Symbols always follow the system text size.
                            """
                        )
                    }
                }
                .errorAlert(presentingError: $error)
        }
    }
}

private extension UpdateLabelsAndSymbolsToScaleForVisualAccessibilityView {
    /// The selected restaurant's name and WGS 84 coordinates.
    func calloutContent(for feature: Feature) -> some View {
        let name = (feature.attributes["name"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let location = (feature.geometry as? Point).flatMap {
            GeometryEngine.project($0, into: .wgs84)
        }
        
        return ScrollView {
            VStack(alignment: .leading) {
                Text(name.flatMap { $0.isEmpty ? nil : $0 } ?? "Restaurant")
                    .font(.headline)
                if let location {
                    Text(
                        """
                        Latitude: \(location.y,
                        format: .number.precision(.fractionLength(5)))
                        """
                    )
                    Text(
                        """
                        Longitude: \(location.x,
                        format: .number.precision(.fractionLength(5)))
                        """
                    )
                }
            }
            .padding(5)
        }
        .frame(maxHeight: 250)
        .fixedSize(horizontal: false, vertical: true)
    }
    
    /// A compact legend showing the current scaling source and values.
    var scalingStatus: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(
                """
                System text scale (Body): \(model.systemTextScale,
                format: .percent.precision(.fractionLength(0)))
                """
            )
            Label {
                Text(
                    model.labelsUseSystemTextScale
                    ? "Labels: Dynamic Type"
                    : "Labels: fixed size"
                )
            } icon: {
                Text("Aa")
                    .bold()
                    .accessibilityHidden(true)
            }
            Label {
                Text(
                    """
                    Symbols: Dynamic Type — \(model.markerSize,
                    format: .number.precision(.fractionLength(1))) pt
                    """
                )
            } icon: {
                Circle()
                    .fill(Color(uiColor: Model.markerColor))
                    .overlay(Circle().stroke(.white, lineWidth: 1.5))
                    .frame(width: 14, height: 14)
                    .accessibilityHidden(true)
            }
        }
        .font(.footnote)
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
    }
    
    /// Opens accessibility settings, with manual guidance if opening fails.
    func openAccessibilitySettings() {
        #if targetEnvironment(macCatalyst)
        let url = URL.accessibilityDisplaySettings
        #else
        let url = URL.accessibilitySettings
        #endif
        openURL(url) { accepted in
            if !accepted {
                error = OpenSettingsError()
            }
        }
    }
    
    /// An error opening settings, including manual navigation instructions.
    struct OpenSettingsError: LocalizedError {
        var errorDescription: String? {
            #if targetEnvironment(macCatalyst)
            String(localized: """
                Unable to open settings. Open System Settings > \
                Accessibility > Display > Text size manually.
                """)
            #else
            String(localized: """
                Unable to open settings. Open Settings > Accessibility > \
                Display & Text Size > Larger Text manually.
                """)
            #endif
        }
    }
}

private extension UpdateLabelsAndSymbolsToScaleForVisualAccessibilityView {
    /// Instructions for trying Dynamic Type scaling in the sample.
    struct TextSizeTip: Tip {
        /// The identifier of the action that opens accessibility settings.
        static let openSettingsActionID = "openSettings"
        
        var title: Text {
            Text("Try changing the system text size")
        }
        
        var message: Text? {
            #if targetEnvironment(macCatalyst)
            Text(
                """
                Open System Settings > Accessibility > Display > Text size \
                to scale restaurant labels and symbols. Text-size support \
                depends on the system and app settings.
                
                Select a restaurant to view its name and coordinates.
                """
            )
            #else
            Text(
                """
                Open Settings > Accessibility > Display & Text Size > \
                Larger Text. Enable Larger Accessibility Sizes for additional \
                sizes, then return to see restaurant labels and symbols scale.
                
                Select a restaurant to view its name and coordinates.
                """
            )
            #endif
        }
        
        var image: Image? {
            Image(systemName: "textformat.size")
        }
        
        var actions: [Action] {
            Action(
                id: Self.openSettingsActionID,
                title: "Open Accessibility Settings"
            )
        }
    }
}

private extension URL {
    /// A best-effort link matching the keyboard-navigation sample.
    /// This undocumented URL may not open Accessibility on every iOS version.
    static var accessibilitySettings: URL {
        URL(string: "App-prefs:ACCESSIBILITY")!
    }
    
    /// The Display pane of macOS Accessibility settings.
    static var accessibilityDisplaySettings: URL {
        URL(
            string: "x-apple.systempreferences:"
                + "com.apple.preference.universalaccess?Seeing_Display"
        )!
    }
}

#Preview {
    NavigationStack {
        UpdateLabelsAndSymbolsToScaleForVisualAccessibilityView()
    }
}
