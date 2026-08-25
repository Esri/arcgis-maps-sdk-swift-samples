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

struct AnalyzeTerrainSuitabilityFromSlopeAndAspectView: View {
    /// The view model for the sample.
    @State private var model = Model()
    /// The selected terrain suitability scenario.
    @State private var selectedScenario = SiteScenario.gentleSouthFacingSlopes
    /// A Boolean value indicating whether the settings are showing.
    @State private var isShowingSettings = false
    /// The identifier for the currently displayed scenario toast.
    @State private var scenarioToastID: UUID?
    /// The error shown in the error alert.
    @State private var error: (any Error)?
    
    var body: some View {
        MapViewReader { mapView in
            MapView(map: model.map, analysisOverlays: [model.analysisOverlay])
                .onAnalysisViewStateChanged { analysis, viewState in
                    guard let activeAnalysis = model.activeAnalysis,
                          analysis === activeAnalysis,
                          let analysisError = viewState.error else {
                        return
                    }
                    error = analysisError
                }
                .overlay(alignment: .top) {
                    if scenarioToastID != nil {
                        Text(selectedScenario.description)
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
                        showScenarioToast()
                    } catch {
                        self.error = error
                    }
                }
                .onChange(of: selectedScenario) {
                    model.showAnalysis(for: selectedScenario)
                    isShowingSettings = false
                    showScenarioToast()
                }
                .errorAlert(presentingError: $error)
        }
    }
    
    private func showScenarioToast() {
        let toastID = UUID()
        withAnimation {
            scenarioToastID = toastID
        }
        Task {
            try? await Task.sleep(for: .seconds(3))
            guard scenarioToastID == toastID else { return }
            withAnimation {
                scenarioToastID = nil
            }
        }
    }
}

// MARK: Extensions

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
