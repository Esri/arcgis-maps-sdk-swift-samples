// Copyright 2024 Esri
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

struct ConfigureElectronicNavigationalChartsView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// The point on the screen where the user tapped.
    @State private var tapPoint: CGPoint?
    
    /// The placement of the selected ENC feature callout.
    @State private var calloutPlacement: CalloutPlacement?
    
    /// A Boolean value indicating whether the display settings view is showing.
    @State private var isShowingDisplaySettings = false
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    var body: some View {
        MapViewReader { mapViewProxy in
            MapView(map: model.map)
                .callout(placement: $calloutPlacement.animation()) { placement in
                    let encFeature = placement.geoElement as! ENCFeature
                    VStack(alignment: .leading) {
                        Text(encFeature.acronym)
                        Text(encFeature.description)
                    }
                    .padding(5)
                }
                .onSingleTapGesture { screenPoint, _ in
                    tapPoint = screenPoint
                }
                .task(id: tapPoint) {
                    // Identifies and selects a tapped feature.
                    guard let tapPoint else {
                        return
                    }
                    
                    do {
                        try await selectENCFeature(screenPoint: tapPoint, proxy: mapViewProxy)
                    } catch {
                        self.error = error
                    }
                }
        }
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button("Display Settings") {
                    isShowingDisplaySettings = true
                }
                .popover(isPresented: $isShowingDisplaySettings) {
                    ENCDisplaySettingsView()
                        .presentationDetents([.fraction(0.5)])
                        .frame(idealWidth: 320, idealHeight: 280)
                }
            }
        }
        .task {
            // Sets up the sample when it opens.
            do {
                try await model.addENCExchangeSet()
                model.configureENCDisplaySettings()
            } catch {
                self.error = error
            }
        }
        .errorAlert(presentingError: $error)
    }
    
    /// Selects an ENC feature identified at a screen point.
    /// - Parameters:
    ///   - screenPoint: The screen coordinate of the geo view at which to identify.
    ///   - proxy: The map view proxy used to identify the screen point.
    private func selectENCFeature(screenPoint: CGPoint, proxy: MapViewProxy) async throws {
        model.encLayer?.clearSelection()
        
        // Uses the proxy to identify the layers at the screen point.
        let identifyResults = try await proxy.identifyLayers(
            screenPoint: screenPoint,
            tolerance: 10
        )
        
        // Gets the ENC layer and feature from the identify results.
        guard let result = identifyResults.first(where: { $0.layerContent is ENCLayer }),
              let encLayer = result.layerContent as? ENCLayer,
              let encFeature = result.geoElements.first as? ENCFeature else {
            return
        }
        
        // Selects the feature using the layer.
        encLayer.select(encFeature)
        model.encLayer = encLayer
        
        // Sets the callout to display on the feature.
        let tapLocation = proxy.location(fromScreenPoint: screenPoint)
        calloutPlacement = .geoElement(encFeature, tapLocation: tapLocation)
    }
}

// MARK: Model

private extension ConfigureElectronicNavigationalChartsView {
    /// The view model for the sample.
    @MainActor
    class Model: ObservableObject {
        /// A map with an oceans basemap.
        let map: Map = {
            let map = Map(basemapStyle: .arcGISOceans)
            map.initialViewpoint = Viewpoint(latitude: -32.5, longitude: 60.95, scale: 67_000)
            return map
        }()
        
        /// The ENC layer for unselecting the selected feature.
        var encLayer: ENCLayer?
        
        /// A URL to the temporary directory for the generated SENC data files.
        private let sencDataURL = FileManager.createTemporaryDirectory()
        
        deinit {
            // Resets ENC environment settings when the sample closes.
            let environmentSettings = ENCEnvironmentSettings.shared
            ENCEnvironmentSettings.shared.resourceURL = nil
            ENCEnvironmentSettings.shared.sencDataURL = nil
            
            try? FileManager.default.removeItem(at: sencDataURL)
            
            let displaySettings = environmentSettings.displaySettings
            displaySettings.marinerSettings.resetToDefaults()
            displaySettings.textGroupVisibilitySettings.resetToDefaults()
            displaySettings.viewingGroupSettings.resetToDefaults()
        }
        
        /// Sets up the ENC exchange set and adds it to the map.
        func addENCExchangeSet() async throws {
            // Sets environment settings for loading the dataset.
            let environmentSettings = ENCEnvironmentSettings.shared
            environmentSettings.resourceURL = .hydrographyData
            environmentSettings.sencDataURL = sencDataURL
            
            // Creates the exchange set from a local file.
            let exchangeSet = ENCExchangeSet(fileURLs: [.exchangeSet])
            try await exchangeSet.load()
            
            // Creates layers from the exchange set's datasets and adds them to the map.
            let encLayers = exchangeSet.datasets.map { dataset in
                ENCLayer(cell: ENCCell(dataset: dataset))
            }
            map.addOperationalLayers(encLayers)
        }
        
        /// Disables some ENC environment display settings to make the chart less cluttered.
        func configureENCDisplaySettings() {
            let displaySettings = ENCEnvironmentSettings.shared.displaySettings
            
            let textGroupVisibilitySettings = displaySettings.textGroupVisibilitySettings
            textGroupVisibilitySettings.includesGeographicNames = false
            textGroupVisibilitySettings.includesNatureOfSeabed = false
            
            let viewingGroupSettings = displaySettings.viewingGroupSettings
            viewingGroupSettings.includesBuoysBeaconsAidsToNavigation = false
            viewingGroupSettings.includesDepthContours = false
            viewingGroupSettings.includesSpotSoundings = false
        }
    }
}

// MARK: ENC Display Settings View

/// A view for adjusting some ENC mariner display settings.
private struct ENCDisplaySettingsView: View {
    /// The action to dismiss the view.
    @Environment(\.dismiss) private var dismiss
    
    /// The color scheme selection.
    @State private var colorScheme: ColorScheme = .day
    
    /// The area symbolization type selection.
    @State private var areaSymbolization: AreaSymbolization = .symbolized
    
    /// The point symbolization type selection.
    @State private var pointSymbolization: PointSymbolization = .paperChart
    
    /// The ENC environment mariner display settings for adjusting the app's ENC rendering.
    private let marinerDisplaySettings = ENCEnvironmentSettings.shared.displaySettings.marinerSettings
    
    // Some ENC mariner settings types.
    private typealias ColorScheme = ENCMarinerSettings.ColorScheme
    private typealias AreaSymbolization = ENCMarinerSettings.AreaSymbolizationType
    private typealias PointSymbolization = ENCMarinerSettings.PointSymbolizationType
    
    var body: some View {
        NavigationStack {
            Form {
                Picker("Color Scheme", selection: $colorScheme) {
                    Text("Day").tag(ColorScheme.day)
                    Text("Dusk").tag(ColorScheme.dusk)
                    Text("Night").tag(ColorScheme.night)
                }
                .onChange(of: colorScheme) { colorScheme in
                    marinerDisplaySettings.colorScheme = colorScheme
                }
                
                Picker("Area Symbolization Type", selection: $areaSymbolization) {
                    Text("Plain").tag(AreaSymbolization.plain)
                    Text("Symbolized").tag(AreaSymbolization.symbolized)
                }
                .onChange(of: areaSymbolization) { areaSymbolization in
                    marinerDisplaySettings.areaSymbolizationType = areaSymbolization
                }
                
                Picker("Point Symbolization Type", selection: $pointSymbolization) {
                    Text("Paper Chart").tag(PointSymbolization.paperChart)
                    Text("Simplified").tag(PointSymbolization.simplified)
                }
                .onChange(of: pointSymbolization) { pointSymbolization  in
                    marinerDisplaySettings.pointSymbolizationType = pointSymbolization
                }
            }
            .navigationTitle("Display Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            colorScheme = marinerDisplaySettings.colorScheme
            areaSymbolization = marinerDisplaySettings.areaSymbolizationType
            pointSymbolization = marinerDisplaySettings.pointSymbolizationType
        }
    }
}

// MARK: Helper Extensions

private extension FileManager {
    /// Creates a temporary directory.
    /// - Returns: The URL of the created directory.
    static func createTemporaryDirectory() -> URL {
        // swiftlint:disable:next force_try
        try! FileManager.default.url(
            for: .itemReplacementDirectory,
            in: .userDomainMask,
            appropriateFor: FileManager.default.temporaryDirectory,
            create: true
        )
    }
}

private extension URL {
    /// The URL to the local ENC exchange set file.
    static var exchangeSet: URL {
        Bundle.main.url(
            forResource: "CATALOG",
            withExtension: "031",
            subdirectory: "ExchangeSetwithoutUpdates/ExchangeSetwithoutUpdates/ENC_ROOT"
        )!
    }
    
    /// The URL to the local hydrography data directory, which contains the ENC resource files.
    static var hydrographyData: URL {
        Bundle.main.url(forResource: "hydrography", withExtension: nil, subdirectory: "hydrography")!
    }
}
