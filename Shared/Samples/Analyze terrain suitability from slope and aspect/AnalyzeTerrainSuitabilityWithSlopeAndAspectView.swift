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
import Foundation
import SwiftUI

struct AnalyzeTerrainSuitabilityWithSlopeAndAspectView: View {
    /// The view model for the sample.
    @State private var model = Model()
    /// The selected terrain suitability scenario.
    @State private var selectedScenario = SiteScenario.gentleSouthFacingSlopes
    /// A Boolean value indicating whether the settings are showing.
    @State private var isShowingSettings = false
    /// The error shown in the error alert.
    @State private var error: (any Error)?
    
    var body: some View {
        MapView(map: model.map, analysisOverlays: [model.analysisOverlay])
            .onAnalysisViewStateChanged { analysis, viewState in
                guard let activeAnalysis = model.activeAnalysis,
                      analysis === activeAnalysis else {
                    return
                }
                model.isUpdatingAnalysis = viewState.status == .updating
                if let analysisError = viewState.error {
                    error = analysisError
                }
            }
            .overlay {
                if model.isUpdatingAnalysis {
                    ProgressView("Updating analysis")
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(.rect(cornerRadius: 8))
                }
            }
            .overlay(alignment: .bottom) {
                Text("Raster data Copyright Scottish Government and SEPA (2014)")
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
                            .frame(idealWidth: 360, idealHeight: 220)
                    }
                }
            }
            .task {
                do {
                    try await model.setUp()
                } catch {
                    self.error = error
                }
            }
            .onChange(of: selectedScenario) {
                model.showAnalysis(for: selectedScenario)
            }
            .errorAlert(presentingError: $error)
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
        AnalyzeTerrainSuitabilityWithSlopeAndAspectView()
    }
}
