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

import Accessibility
import ArcGIS
import SwiftUI
import TipKit

struct UpdateLabelsAndSymbolsToScaleForVisualAccessibilityView: View {
    /// The view model for the sample.
    @State private var model = Model()
    
    /// The map displaying restaurants in Redlands, California.
    @State private var map: Map = {
        let map = Map(basemapStyle: .arcGISLightGray)
        map.initialViewpoint = Viewpoint(
            latitude: 34.0556,
            longitude: -117.1793,
            scale: 2_500
        )
        return map
    }()
    
    /// An error from identifying a restaurant, loading the layer,
    /// configuring tips, or opening settings.
    @State private var error: (any Error)?
    
    /// Opens the platform's accessibility settings.
    @Environment(\.openURL) private var openURL
    
    /// The text size used to decide whether to show inline instructions.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    /// Whether the available layout has a compact height.
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    /// Whether the text-size instructions are presented.
    @State private var isShowingTextSizeHelp = false
    
    /// The legend's content height before any scrolling is needed.
    @State private var scalingStatusHeight: CGFloat?

    /// The map height available above the bottom controls.
    @State private var mapHeight: CGFloat = 0

    /// The callout's content height before any scrolling is needed.
    @State private var calloutContentHeight: CGFloat?

    /// The latest identify request, with a unique ID so repeated taps
    /// at the same point restart the task.
    @State private var identifyRequest: IdentifyRequest?
    
    /// The selected restaurant whose details are shown in the callout, if any.
    @State private var selectedFeature: Feature?
    
    /// The placement of the restaurant details callout, or `nil` when hidden.
    @State private var calloutPlacement: CalloutPlacement?
    
    /// A scale factor relative to the default body text size.
    @ScaledMetric(relativeTo: .body) private var systemTextScale: CGFloat = 1
    
    var body: some View {
        VStack(spacing: 0) {
            mapContent
                .onGeometryChange(for: CGFloat.self) { geometry in
                    geometry.size.height
                } action: { height in
                    mapHeight = height
                }
            scalingControls
        }
    }

    /// The map and its selection, tip, and help interactions.
    private var mapContent: some View {
        MapViewReader { mapView in
            MapView(map: map)
                .callout(placement: $calloutPlacement) { _ in
                    if let selectedFeature {
                        calloutContent(for: selectedFeature)
                    }
                }
                .onSingleTapGesture { screenPoint, _ in
                    model.restaurantsLayer.clearSelection()
                    selectedFeature = nil
                    calloutPlacement = nil
                    identifyRequest = IdentifyRequest(screenPoint: screenPoint)
                }
                .task(id: identifyRequest?.id) {
                    guard let identifyRequest else { return }
                    do {
                        // Identify at most one restaurant near the tap.
                        let result = try await mapView.identify(
                            on: model.restaurantsLayer,
                            screenPoint: identifyRequest.screenPoint,
                            tolerance: 12,
                            maximumResults: 1
                        )
                        // Don't show stale results after another tap
                        // or dismissal.
                        try Task.checkCancellation()
                        guard
                            let feature = result.geoElements.first as? Feature,
                            let location = feature.geometry as? Point
                        else {
                            return
                        }
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
                    // Avoid adding the layer again when the view reappears.
                    if map.operationalLayers.isEmpty {
                        map.addOperationalLayer(model.restaurantsLayer)
                    }
                    
                    // Configure tips on a best-effort basis, ignoring failures
                    // such as tips already being configured for this process.
                    try? Tips.configure([.displayFrequency(.immediate)])
                }
                .overlay(alignment: .top) {
                    if verticalSizeClass != .compact
                        && !dynamicTypeSize.isAccessibilitySize {
                        ViewThatFits(in: .vertical) {
                            TipView(TextSizeTip()) { _ in
                                openAccessibilitySettings()
                            }
                            .fixedSize(horizontal: false, vertical: true)
                            .padding()
                            // Help remains available if the tip cannot fit.
                            Color.clear
                                .allowsHitTesting(false)
                        }
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            isShowingTextSizeHelp = true
                        } label: {
                            Label(
                                "Text Size Help",
                                systemImage: "textformat.size"
                            )
                        }
                    }
                }
                .sheet(isPresented: $isShowingTextSizeHelp) {
                    textSizeHelp
                }
                .errorAlert(presentingError: Binding(
                    get: { isShowingTextSizeHelp ? nil : error },
                    set: { error = $0 }
                ))
        }
    }
}

private extension UpdateLabelsAndSymbolsToScaleForVisualAccessibilityView {
    /// A uniquely identified map tap and the screen point to identify.
    struct IdentifyRequest {
        /// A unique task ID so each tap starts a new identify operation.
        let id = UUID()
        
        /// The tapped position in the map view's screen coordinates.
        let screenPoint: CGPoint
    }
    
    /// The selected restaurant's name and WGS 84 coordinates.
    func calloutContent(for feature: Feature) -> some View {
        let name = (feature.attributes["name"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let location = (feature.geometry as? Point).flatMap {
            GeometryEngine.project($0, into: .wgs84)
        }
        let coordinateFormat = FloatingPointFormatStyle<Double>.number
            .precision(.fractionLength(5))
        
        return ScrollView {
            VStack(alignment: .leading) {
                Text(name.flatMap { $0.isEmpty ? nil : $0 } ?? "Restaurant")
                    .font(.headline)
                if let location {
                    Text("Latitude: \(location.y, format: coordinateFormat)")
                    Text("Longitude: \(location.x, format: coordinateFormat)")
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding()
            .onGeometryChange(for: CGFloat.self) { geometry in
                geometry.size.height
            } action: { height in
                calloutContentHeight = height
            }
        }
        // Let the callout container propose a smaller scrolling viewport.
        .frame(maxHeight: min(calloutContentHeight ?? mapHeight, mapHeight))
    }
    
    /// Content-sized controls, with a legend when space and text size permit.
    var scalingControls: some View {
        VStack(alignment: .leading) {
            if verticalSizeClass != .compact
                && !dynamicTypeSize.isAccessibilitySize {
                ScrollView {
                    scalingStatus
                        .fixedSize(horizontal: false, vertical: true)
                        .onGeometryChange(for: CGFloat.self) { geometry in
                            geometry.size.height
                        } action: { height in
                            scalingStatusHeight = height
                        }
                }
                .frame(maxHeight: scalingStatusHeight)
            }
            labelScalingToggle
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial)
    }
    
    /// The label-scaling control below the map.
    var labelScalingToggle: some View {
        @Bindable var model = model
        
        return Toggle("Scale Labels", isOn: $model.labelsUseSystemTextScale)
            .toggleStyle(.switch)
            .accessibilityHint(
                """
                Apply system text size to restaurant labels. \
                Symbols always follow the system text size.
                """
            )
    }
    
    /// Instructions available when the inline tip is hidden or dismissed.
    var textSizeHelp: some View {
        NavigationStack {
            Form {
                Self.textSizeInstructions
                Button("Open Accessibility Settings") {
                    openAccessibilitySettings()
                }
            }
            .navigationTitle("Text Size")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isShowingTextSizeHelp = false
                    }
                }
            }
            .errorAlert(presentingError: $error)
        }
        .presentationDetents([.medium, .large])
    }
    
    /// A compact legend showing the current scaling source and values.
    var scalingStatus: some View {
        let scaleFormat = FloatingPointFormatStyle<CGFloat>.Percent()
            .precision(.fractionLength(0))
        let markerFormat = FloatingPointFormatStyle<CGFloat>()
            .precision(.fractionLength(1))
        
        return VStack(alignment: .leading) {
            Text(
                """
                System text scale (Body): \
                \(model.systemTextScale, format: scaleFormat)
                """
            )
            Label {
                Text(
                    model.labelsUseSystemTextScale
                        ? "Labels: Dynamic Type" : "Labels: fixed size"
                )
            } icon: {
                Text("Aa")
                    .bold()
                    .accessibilityHidden(true)
            }
            Label {
                Text(
                    """
                    Symbols: Dynamic Type — \
                    \(model.markerSize, format: markerFormat) pt
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
        .font(.body)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    /// Opens accessibility settings, with manual guidance if opening fails.
    func openAccessibilitySettings() {
        #if targetEnvironment(macCatalyst)
        openURL(.accessibilityDisplaySettings) { accepted in
            if !accepted {
                error = OpenSettingsError()
            }
        }
        #else
        Task {
            do {
                // Use destinations supported by the current iOS version.
                // The API has no explicit destination for Larger Text.
                if #available(iOS 26.0, *) {
                    try await AccessibilitySettings.openSettings(
                        for: .assistiveTouchDevices
                    )
                } else {
                    try await AccessibilitySettings.openSettings(
                        for: .personalVoiceAllowAppsToRequestToUse
                    )
                }
            } catch {
                self.error = OpenSettingsError()
            }
        }
        #endif
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

private extension URL {
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
