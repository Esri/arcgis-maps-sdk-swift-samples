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
import UIKit

struct UpdateBasemapForContrastAccessibilityView: View {
    /// The one-time TipKit configuration for this sample.
    private static let tipConfiguration: Void = {
        try? Tips.configure([.displayFrequency(.immediate)])
    }()
    
    /// The view model for the sample.
    @State private var model = Model()
    
    /// The error shown in an alert, if any.
    @State private var error: (any Error)?
    
    /// A Boolean value indicating whether the settings view should be presented.
    @State private var isShowingSettings = false
    
    /// The system color scheme (light or dark).
    @Environment(\.colorScheme) private var colorScheme
    
    /// The system contrast setting (standard or increased).
    ///
    /// Reflects the "Increase Contrast" accessibility preference.
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    
    /// The contrast appearance resolved from the current SwiftUI environment values.
    ///
    /// SwiftUI re-evaluates this whenever the color scheme or contrast values change.
    private var appearanceForDeviceSettings: ContrastAppearance {
        ContrastAppearance(colorScheme: colorScheme, contrast: colorSchemeContrast)
    }
    
    /// The contrast appearance that should be displayed for the current mode.
    private var appearanceForCurrentMode: ContrastAppearance {
        switch model.contrastMode {
        case .automatic: appearanceForDeviceSettings
        case .manual: model.contrastAppearance
        }
    }
    
    init() {
        _ = Self.tipConfiguration
    }
    
    var body: some View {
        MapView(map: model.map)
            .task(id: appearanceForCurrentMode) {
                do {
                    try await model.setBasemap(for: appearanceForCurrentMode)
                } catch {
                    self.error = error
                }
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button("Contrast Options") {
                        isShowingSettings = true
                    }
                    .sheet(isPresented: $isShowingSettings) {
                        SettingsView(model: model)
                            .presentationDetents([.medium, .large])
                    }
                }
            }
            .errorAlert(presentingError: $error)
    }
}

private extension UpdateBasemapForContrastAccessibilityView {
    // MARK: - Settings View
    
    /// The appearance settings for the map.
    struct SettingsView: View {
        /// The view model for the sample.
        @Bindable var model: Model
        
        /// The action to dismiss the view.
        @Environment(\.dismiss) private var dismiss
        
        /// A tip explaining how the automatic contrast mode responds to OS settings.
        private let automaticModeTip = AutomaticModeTip()
        
        var body: some View {
            NavigationStack {
                Form {
                    Section {
                        Toggle("Reference Layers", isOn: $model.referenceLayersAreVisible)
                    } footer: {
                        Text(
                            model.referenceLayersAreVisible
                            ? "Labels and boundary reference layers are visible."
                            : "Labels and boundary reference layers are hidden."
                        )
                        .font(.caption)
                    }
                    
                    Section {
                        Picker("Mode", selection: $model.contrastMode) {
                            ForEach(ContrastMode.allCases, id: \.self) { mode in
                                Text(mode.displayName)
                            }
                        }
                        .pickerStyle(.segmented)
                    } header: {
                        Text("Visual Contrast Mode")
                    } footer: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(model.contrastMode.detail)
                            
                            if model.contrastMode == .automatic {
                                TipView(automaticModeTip) { action in
                                openAccessibilitySettings()
                                }
                            }
                        }
                    }
                    if model.contrastMode == .manual {
                        Section("Manual Contrast") {
                            Picker("Appearance", selection: $model.contrastAppearance) {
                                ForEach(ContrastAppearance.allCases, id: \.self) { appearance in
                                    VStack(alignment: .leading) {
                                        Text(appearance.displayName)
                                        Text(appearance.detail)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .pickerStyle(.inline)
                            .labelsHidden()
                        }
                    }
                }
                .navigationTitle("Contrast Options")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
        }
        
        /// Opens the Settings app to an Accessibility feature when supported.
        private func openAccessibilitySettings() {
            Task {
                do {
                    if #available(iOS 26.0, *) {
                        let feature: AccessibilitySettings.Feature = .assistiveTouch
                        try await AccessibilitySettings.openSettings(for: feature)
                    } else if #available(iOS 18.0, *) {
                        let feature: AccessibilitySettings.Feature = .personalVoiceAllowAppsToRequestToUse
                        try await AccessibilitySettings.openSettings(for: feature)
                    } else {
                        openAppSettings()
                    }
                } catch {
                    print("Unable to open Accessibility Settings: \(error)")
                    openAppSettings()
                }
            }
        }
        
        /// Opens this app's page in the Settings app.
        private func openAppSettings() {
            UIApplication.shared.open(.appSettings)
        }
    }
}

private extension UpdateBasemapForContrastAccessibilityView {
    /// A tip that guides users to test automatic mode using OS appearance settings.
    struct AutomaticModeTip: Tip {
        /// The ID of the action that opens the Settings app.
        static let openSettingsActionID = "openSettings"
        
        var title: Text {
            Text("Try changing device appearance")
        }
        
        var message: Text? {
            Text(
                """
                Change Light/Dark Mode or Increase Contrast in the Settings app
                to see the basemap update automatically. Increase Contrast is in
                Accessibility > Display & Text Size.
                """
            )
        }
        
        var image: Image? {
            Image(systemName: "gearshape")
        }
        
        var actions: [Action] {
            Action(
                id: Self.openSettingsActionID,
                title: "Open Accessibility Settings"
            )
        }
    }
}

private extension UpdateBasemapForContrastAccessibilityView {
    @MainActor
    @Observable
    final class Model {
        /// The map displayed in the map view.
        var map: Map
        
        /// Whether the appearance is resolved automatically or chosen manually.
        var contrastMode: ContrastMode = .automatic
        
        /// The contrast appearance currently driving the basemap.
        ///
        /// In manual mode this is bound to the picker; in automatic mode it tracks
        /// whatever the device settings most recently resolved to.
        var contrastAppearance: ContrastAppearance = .light
        
        /// Whether the basemap's reference layers are visible.
        var referenceLayersAreVisible = true {
            didSet {
                map.basemap?.referenceLayers.forEach { layer in
                    layer.isVisible = referenceLayersAreVisible
                }
            }
        }
        
        init() {
            map = Map()
            map.initialViewpoint = .redlands
        }
        
        /// Sets the map's basemap to match `contrast`, then loads it and applies
        /// the current reference-layer visibility.
        func setBasemap(for contrast: ContrastAppearance) async throws {
            // Always update the contrast appearance to keep it in sync.
            contrastAppearance = contrast
            // Create and load a new basemap for the existing map.
            let basemap = Self.makeBasemap(for: contrast)
            map.basemap = basemap
            // Reference layers are only available once the basemap has loaded.
            try await basemap.load()
            // Apply the current reference-layer visibility to the loaded basemap.
            basemap.referenceLayers.forEach { layer in
                layer.isVisible = referenceLayersAreVisible
            }
        }
        
        /// Maps the selected appearance to its contrast-accessibility basemap.
        private static func makeBasemap(for contrast: ContrastAppearance) -> Basemap {
            switch contrast {
            case .light:
                Basemap(style: .arcGISLightGray)
            case .dark:
                Basemap(style: .arcGISDarkGray)
            case .highContrastLight:
                Basemap(url: .highContrastLightBasemap)!
            case .highContrastDark:
                Basemap(url: .highContrastDarkBasemap)!
            }
        }
    }
}

private extension UpdateBasemapForContrastAccessibilityView {
    /// The mode of the device's color and contrast appearance, chosen automatically or manually.
    enum ContrastMode: CaseIterable, Hashable {
        case automatic
        case manual
        
        var displayName: String {
            switch self {
            case .automatic: "Automatic"
            case .manual: "Manual"
            }
        }
        
        var detail: String {
            switch self {
            case .automatic: "Use device light, dark, and high-contrast settings to auto-select the basemap."
            case .manual: "Choose one of the four basemaps manually."
            }
        }
    }
    
    /// The contrast appearance variants.
    enum ContrastAppearance: CaseIterable, Hashable {
        case light
        case dark
        case highContrastLight
        case highContrastDark
        
        /// Creates an appearance from the current SwiftUI environment settings.
        init(colorScheme: ColorScheme, contrast: ColorSchemeContrast) {
            switch colorScheme {
            case .dark:
                self = contrast == .increased ? .highContrastDark : .dark
            default:
                self = contrast == .increased ? .highContrastLight : .light
            }
        }
        
        var displayName: String {
            switch self {
            case .light: "Light"
            case .dark: "Dark"
            case .highContrastLight: "High Contrast Light"
            case .highContrastDark: "High Contrast Dark"
            }
        }
        
        var detail: String {
            switch self {
            case .light: "Regular light basemap for regular light theme."
            case .dark: "Regular dark basemap for regular dark theme."
            case .highContrastLight: "High-contrast light basemap for enhanced light theme."
            case .highContrastDark: "High-contrast dark basemap for enhanced dark theme."
            }
        }
    }
}

private extension URL {
    /// The URL of this app's page in the Settings app.
    static var appSettings: URL {
        URL(string: UIApplication.openSettingsURLString)!
    }
    
    /// The URL of the high-contrast light basemap item.
    static var highContrastLightBasemap: URL {
        URL(string: "https://www.arcgis.com/home/item.html?id=084291b0ecad4588b8c8853898d72445")!
    }
    
    /// The URL of the high-contrast dark basemap item.
    static var highContrastDarkBasemap: URL {
        URL(string: "https://www.arcgis.com/home/item.html?id=3e23478909194c54992eaaee78b5f754")!
    }
}

private extension Viewpoint {
    static var redlands: Viewpoint {
        Viewpoint(latitude: 34.05, longitude: -117.19, scale: 2e6)
    }
}

#Preview {
    NavigationStack {
        UpdateBasemapForContrastAccessibilityView()
    }
}
