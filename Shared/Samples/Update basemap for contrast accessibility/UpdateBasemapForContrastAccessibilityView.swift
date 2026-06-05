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

struct UpdateBasemapForContrastAccessibilityView: View {
    /// The view model for the sample.
    @State private var model = Model()
    
    /// A Boolean value indicating whether the settings sheet is presented.
    @State private var isShowingSettings = false
    
    /// The system color scheme (light or dark).
    ///
    @Environment(\.colorScheme) private var colorScheme
    
    /// The system contrast setting (standard or increased).
    ///
    /// Reflects the "Increase Contrast" accessibility preference and is the iOS
    /// counterpart to Android's `UiModeManager.contrast` / high-text-contrast secure settings.
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    
    /// The appearance resolved purely from the current device settings.
    ///
    /// SwiftUI re-evaluates this whenever the user changes Dark Mode or Increase
    /// Contrast, so no `ContentObserver` or change listener is required.
    private var automaticAppearance: ContrastAppearance {
        switch (colorSchemeContrast, colorScheme) {
        case (.increased, .dark): .highContrastDark
        case (.increased, _): .highContrastLight
        case (_, .dark): .dark
        default: .light
        }
    }
    
    /// The appearance that should drive the displayed basemap, honoring the selected mode.
    private var effectiveAppearance: ContrastAppearance {
        switch model.contrastMode {
        case .automatic: automaticAppearance
        case .manual: model.contrastAppearance
        }
    }
    
    var body: some View {
        MapView(map: model.map)
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button("Contrast Options") { isShowingSettings = true }
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                NavigationStack {
                    ContrastSettingsView(model: model)
                        .navigationTitle("Contrast Options")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { isShowingSettings = false }
                            }
                        }
                }
                .presentationDetents([.medium, .large])
            }
            .alert(
                "Error",
                isPresented: Binding(
                    get: { model.error != nil },
                    set: { if !$0 { model.error = nil } }
                ),
                presenting: model.error
            ) { _ in
                Button("OK", role: .cancel) { model.error = nil }
            } message: { error in
                Text(error.localizedDescription)
            }
            .onChange(of: effectiveAppearance) { _, newAppearance in
                Task {
                    await model.update(to: newAppearance)
                }
            }
            .task {
                // Initial load.
                await model.update(to: effectiveAppearance)
            }
    }
}

private extension UpdateBasemapForContrastAccessibilityView {
    // MARK: - Settings View
    
    /// The controls that drive the displayed map, presented as a settings sheet
    /// (the iOS counterpart to the Android supporting pane).
    struct ContrastSettingsView: View {
        /// The view model for the sample.
        @Bindable var model: Model
        
        var body: some View {
            Form {
                Section {
                    Toggle("Reference Layers", isOn: $model.areReferenceLayersEnabled)
                } footer: {
                    Text(
                        model.areReferenceLayersEnabled
                        ? "Labels and boundary reference layers are visible."
                        : "Labels and boundary reference layers are hidden."
                    )
                }
                
                Section {
                    Picker("Mode", selection: $model.contrastMode) {
                        ForEach(ContrastMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.inline)
                } header: {
                    Text("Visual Contrast Mode")
                } footer: {
                    Text(model.contrastMode.detail)
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
                                .tag(appearance)
                            }
                        }
                        .pickerStyle(.inline)
                    }
                }
            }
        }
    }
}

private extension UpdateBasemapForContrastAccessibilityView {
    // MARK: - Model
    
    /// The model for the sample. It owns the displayed map and keeps it in sync
    /// with the selected contrast appearance.
    @MainActor
    @Observable
    final class Model {
        /// The map displayed in the map view.
        var map = Map(basemapStyle: .arcGISStreets)
        
        /// Whether the appearance is resolved automatically or chosen manually.
        var contrastMode: ContrastMode = .automatic
        
        /// The contrast appearance currently driving the basemap.
        ///
        /// In manual mode this is bound to the picker; in automatic mode it tracks
        /// whatever the device settings most recently resolved to.
        var contrastAppearance: ContrastAppearance = .highContrastLight
        
        /// Whether the basemap's reference layers are visible.
        var areReferenceLayersEnabled = true {
            didSet { applyReferenceLayersVisibility() }
        }
        
        /// The error shown in an alert, if any.
        var error: Error?
        
        init() {
            map = Self.makeMap(for: contrastAppearance)
        }
        
        /// Ensures the displayed basemap matches `contrast`, then loads it and
        /// applies the current reference-layer visibility.
        func update(to contrast: ContrastAppearance) async {
            // Always update the contrast appearance to keep it in sync.
            contrastAppearance = contrast
            
            // Create a new map with the appropriate basemap.
            map = Self.makeMap(for: contrast)
            
            do {
                // Reference layers are only available once the basemap has loaded.
                try await map.load()
                applyReferenceLayersVisibility()
            } catch {
                self.error = error
            }
        }
        
        /// Applies the current reference-layer visibility flag to the loaded basemap.
        private func applyReferenceLayersVisibility() {
            map.basemap?.referenceLayers.forEach { layer in
                layer.isVisible = areReferenceLayersEnabled
            }
        }
        
        /// Builds an unloaded map for the given appearance.
        private static func makeMap(for contrast: ContrastAppearance) -> Map {
            let map = Map(basemap: basemap(for: contrast))
            map.initialViewpoint = sampleViewpoint
            return map
        }
        
        /// The default viewpoint used for the map.
        private static let sampleViewpoint = Viewpoint(
            latitude: 34.05,
            longitude: -117.19,
            scale: 2e6
        )
        
        /// Maps the selected appearance to its contrast-accessibility basemap.
        private static func basemap(for contrast: ContrastAppearance) -> Basemap {
            switch contrast {
            case .light:
                Basemap(style: .arcGISLightGray)
            case .dark:
                Basemap(style: .arcGISDarkGray)
            case .highContrastLight:
                Basemap(url: URL(string: "https://www.arcgis.com/home/item.html?id=084291b0ecad4588b8c8853898d72445")!)!
            case .highContrastDark:
                Basemap(url: URL(string: "https://www.arcgis.com/home/item.html?id=3e23478909194c54992eaaee78b5f754")!)!
            }
        }
    }
}

private extension UpdateBasemapForContrastAccessibilityView {
    // MARK: - Helper Types
    
    /// Tracks whether the appearance comes from device settings or the manual picker.
    enum ContrastMode: CaseIterable {
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
    
    /// The four contrast appearance variants.
    enum ContrastAppearance: CaseIterable {
        case light
        case highContrastLight
        case dark
        case highContrastDark
        
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

#Preview {
    NavigationStack {
        UpdateBasemapForContrastAccessibilityView()
    }
}
