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
// limitations under the License

import ArcGIS
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

// MARK: Model

/// The view model for this sample.
@MainActor
@Observable
private final class Model {
    /// The UTM zone 30N spatial reference used by the map and field analysis.
    private static let utm30N = SpatialReference(wkid: WKID(32630)!)!

    /// A blank map using a conformal spatial reference supported by slope and aspect operations.
    let map = Map(spatialReference: Model.utm30N)
    /// The overlay used to display the terrain suitability analyses.
    let analysisOverlay = AnalysisOverlay()
    /// A Boolean value indicating whether the active analysis is updating.
    var isUpdatingAnalysis = false

    /// The analysis for gentle south-facing, lowland slopes.
    private var gentleSouthFacingSlopesAnalysis: FieldAnalysis?
    /// The analysis for steep, upland west- through north-facing slopes.
    private var steepWestAndNorthFacingSlopesAnalysis: FieldAnalysis?
    /// The currently selected scenario.
    private var selectedScenario = SiteScenario.gentleSouthFacingSlopes

    /// The active analysis, used to monitor its rendering state.
    var activeAnalysis: FieldAnalysis? {
        switch selectedScenario {
        case .gentleSouthFacingSlopes:
            gentleSouthFacingSlopesAnalysis
        case .steepWestAndNorthFacingSlopes:
            steepWestAndNorthFacingSlopesAnalysis
        }
    }

    /// Creates the terrain suitability analyses from the local elevation raster.
    func setUp() async throws {
        isUpdatingAnalysis = true
        defer { isUpdatingAnalysis = false }

        // Project the Web Mercator elevation raster into UTM30N. Slope and
        // aspect operations require a conformal projected coordinate system.
        let elevationField = try await ContinuousField.field(
            fromFilesAt: [.arranElevation],
            bandIndex: 0,
            spatialReference: Self.utm30N
        )
        let elevationFunction = ContinuousFieldFunction.function(withResult: elevationField)
        let slopeFunction = elevationFunction.slope()
        let aspectFunction = elevationFunction.aspect()
        let aboveSeaLevelSelection = elevationFunction.isGreaterThanOrEqualTo(0)
        let inputs = TerrainAnalysisInputs(
            slopeFunction: slopeFunction,
            aspectFunction: aspectFunction,
            elevationFunction: elevationFunction,
            aboveSeaLevelSelection: aboveSeaLevelSelection
        )

        gentleSouthFacingSlopesAnalysis = makeAnalysis(
            inputs: inputs,
            criteria: .gentleSouthFacingSlopes,
            color: .systemGreen
        )
        steepWestAndNorthFacingSlopesAnalysis = makeAnalysis(
            inputs: inputs,
            criteria: .steepWestAndNorthFacingSlopes,
            color: .systemPurple
        )

        if let gentleSouthFacingSlopesAnalysis,
           let steepWestAndNorthFacingSlopesAnalysis {
            analysisOverlay.addAnalyses([
                gentleSouthFacingSlopesAnalysis,
                steepWestAndNorthFacingSlopesAnalysis
            ])
        }
        showAnalysis(for: selectedScenario)
        map.initialViewpoint = Viewpoint(center: elevationField.extent.center, scale: 200_000)
    }

    /// Shows the analysis for the given terrain suitability scenario.
    /// - Parameter scenario: The scenario whose analysis should be visible.
    func showAnalysis(for scenario: SiteScenario) {
        selectedScenario = scenario
        isUpdatingAnalysis = true
        gentleSouthFacingSlopesAnalysis?.isVisible = scenario == .gentleSouthFacingSlopes
        steepWestAndNorthFacingSlopesAnalysis?.isVisible = scenario == .steepWestAndNorthFacingSlopes
    }

    /// Creates a field analysis for the supplied slope, aspect, and elevation ranges.
    private func makeAnalysis(
        inputs: TerrainAnalysisInputs,
        criteria: TerrainCriteria,
        color: UIColor
    ) -> FieldAnalysis {
        // The long-form methods and logicalAnd can be used instead of these
        // operator overloads. The overloads make chained range checks concise.
        let slopeRangeMask = (inputs.slopeFunction .>= criteria.slopeRange.lowerBound) .&
            (inputs.slopeFunction .<= criteria.slopeRange.upperBound)
        let elevationRangeMask = (inputs.elevationFunction .>= criteria.elevationRange.lowerBound) .&
            (inputs.elevationFunction .<= criteria.elevationRange.upperBound)

        // An aspect range whose start is greater than its end crosses north.
        let aspectRangeMask: BooleanFieldFunction
        if criteria.aspectStart <= criteria.aspectEnd {
            aspectRangeMask = (inputs.aspectFunction .>= criteria.aspectStart) .&
                (inputs.aspectFunction .<= criteria.aspectEnd)
        } else {
            aspectRangeMask = ((inputs.aspectFunction .>= criteria.aspectStart) .&
                (inputs.aspectFunction .< 360)) .|
                ((inputs.aspectFunction .>= 0) .& (inputs.aspectFunction .<= criteria.aspectEnd))
        }

        // Keep land above sea level and assign zero or one to each remaining pixel.
        let scenarioFunction = slopeRangeMask
            .logicalAnd(with: aspectRangeMask)
            .logicalAnd(with: elevationRangeMask)
            .mask(selection: inputs.aboveSeaLevelSelection)
            .toDiscreteFieldFunction()
        let renderer = ColormapRenderer(colors: [.white, color])
        let analysis = FieldAnalysis(function: scenarioFunction, renderer: renderer)
        analysis.isVisible = false
        return analysis
    }
}

// MARK: Helper Views

/// Controls for choosing a preconfigured terrain suitability scenario.
private struct TerrainSuitabilitySettings: View {
    /// The selected terrain suitability scenario.
    @Binding var selectedScenario: SiteScenario

    var body: some View {
        NavigationStack {
            Form {
                Section("Sheltered vs Exposed Terrain Suitability") {
                    Picker("Scenario", selection: $selectedScenario) {
                        ForEach(SiteScenario.allCases) { scenario in
                            Text(scenario.title).tag(scenario)
                        }
                    }
                    .pickerStyle(.inline)

                    Text(selectedScenario.description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

// MARK: Supporting Types

/// The field functions used by each terrain suitability analysis.
private struct TerrainAnalysisInputs {
    let slopeFunction: ContinuousFieldFunction
    let aspectFunction: ContinuousFieldFunction
    let elevationFunction: ContinuousFieldFunction
    let aboveSeaLevelSelection: BooleanFieldFunction
}

/// The slope, aspect, and elevation constraints for a terrain suitability analysis.
private struct TerrainCriteria {
    let slopeRange: ClosedRange<Float>
    let aspectStart: Float
    let aspectEnd: Float
    let elevationRange: ClosedRange<Float>

    static let gentleSouthFacingSlopes = TerrainCriteria(
        slopeRange: 0...20,
        aspectStart: 112.5,
        aspectEnd: 247.5,
        elevationRange: 0...300
    )
    static let steepWestAndNorthFacingSlopes = TerrainCriteria(
        slopeRange: 20...80,
        aspectStart: 202.5,
        aspectEnd: 67.5,
        elevationRange: 300...850
    )
}

/// Preconfigured terrain suitability scenarios.
private enum SiteScenario: CaseIterable, Identifiable {
    case gentleSouthFacingSlopes
    case steepWestAndNorthFacingSlopes

    var id: Self { self }

    var title: String {
        switch self {
        case .gentleSouthFacingSlopes:
            "Gentle, lowland south-facing slopes"
        case .steepWestAndNorthFacingSlopes:
            "Steep, upland west- through north-facing slopes"
        }
    }

    var description: String {
        switch self {
        case .gentleSouthFacingSlopes:
            "Finds sheltered, lowland terrain with gentle south-facing slopes."
        case .steepWestAndNorthFacingSlopes:
            "Finds exposed, upland terrain with steep west- through north-facing slopes."
        }
    }
}

// MARK: Extensions

private extension URL {
    /// A URL to the local GeoTIFF elevation raster of the Isle of Arran, Scotland.
    static var arranElevation: URL {
        Bundle.main.url(forResource: "arran", withExtension: "tif", subdirectory: "arran")!
    }
}

#Preview {
    NavigationStack {
        AnalyzeTerrainSuitabilityWithSlopeAndAspectView()
    }
}
