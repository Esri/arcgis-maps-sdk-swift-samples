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

/// A view that analyzes elevation data to find terrain matching a selected slope and aspect scenario.
struct AnalyzeTerrainSuitabilityFromSlopeAndAspectView: View {
    /// The view model for the sample.
    @State private var model = Model()
    /// The selected terrain suitability scenario.
    @State private var selectedScenario = SiteScenario.gentleSouthFacingSlopes
    /// A Boolean value indicating whether the settings are showing.
    @State private var isShowingSettings = false
    /// The identifier for the currently displayed scenario toast. This is needed to trigger the toast dismissal task when the scenario changes.
    @State private var scenarioToastID: UUID?
    /// The error shown in the error alert.
    @State private var error: (any Error)?
    
    /// The map and controls used to display and configure the terrain suitability analysis.
    var body: some View {
        MapViewReader { mapView in
            MapView(map: model.map, analysisOverlays: [model.analysisOverlay])
                .onAnalysisViewStateChanged { analysis, viewState in
                    guard let activeAnalysis = model.activeAnalysis,
                          analysis === activeAnalysis else {
                        return
                    }
                    if let analysisError = viewState.error {
                        error = analysisError
                    }
                }
                .overlay(alignment: .top) {
                    if scenarioToastID != nil {
                        Text(selectedScenario.description)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(.regularMaterial)
                            .clipShape(.rect(cornerRadius: 8))
                            .padding()
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .overlay(alignment: .bottom) {
                    Text("Raster data copyright Scottish Government and SEPA (2014)")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(.thinMaterial, ignoresSafeAreaEdges: .horizontal)
                }
                .toolbar {
                    ToolbarItem(placement: .bottomBar) {
                        Button("Settings", systemImage: "gear") {
                            isShowingSettings.toggle()
                        }
                        .popover(isPresented: $isShowingSettings) {
                            TerrainSuitabilitySettings(selectedScenario: $selectedScenario)
                                .presentationCompactAdaptation(.popover)
                                .frame(idealWidth: 320, idealHeight: 340)
                        }
                    }
                }
                .task {
                    do {
                        let viewpoint = try await model.setUp()
                        await mapView.setViewpoint(viewpoint)
                        withAnimation {
                            scenarioToastID = UUID()
                        }
                    } catch {
                        self.error = error
                    }
                }
                .task(id: scenarioToastID) {
                    guard scenarioToastID != nil else { return }
                    
                    try? await Task.sleep(for: .seconds(3))
                    guard !Task.isCancelled else { return }
                    
                    withAnimation {
                        scenarioToastID = nil
                    }
                }
                .onChange(of: selectedScenario) {
                    model.showAnalysis(for: selectedScenario)
                    isShowingSettings = false
                    withAnimation {
                        scenarioToastID = UUID()
                    }
                }
                .errorAlert(presentingError: $error)
        }
    }
}

// MARK: Extensions

/// Provides access to the local raster data used by the terrain suitability analysis.
extension URL {
    /// A URL to the local GeoTIFF elevation raster of the Isle of Arran, Scotland.
    static func terrainSuitabilityArranElevation() throws -> URL {
        guard let url = Bundle.main.url(
            forResource: "arran",
            withExtension: "tif",
            subdirectory: "arran"
        ) else {
            throw URLError(.fileDoesNotExist)
        }
        return url
    }
}

#Preview {
    NavigationStack {
        AnalyzeTerrainSuitabilityFromSlopeAndAspectView()
    }
}
