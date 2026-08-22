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
import UIKit

extension AnalyzeTerrainSuitabilityFromSlopeAndAspectView {
    @MainActor
    @Observable
    final class Model {
        private static let utm30N = SpatialReference(wkid: WKID(32630)!)!
        
        let map = Map(spatialReference: Model.utm30N)
        let analysisOverlay = AnalysisOverlay()
        var isUpdatingAnalysis = false
        
        private var gentleSouthFacingSlopesAnalysis: FieldAnalysis?
        private var steepWestAndNorthFacingSlopesAnalysis: FieldAnalysis?
        private var selectedScenario = SiteScenario.gentleSouthFacingSlopes
        
        var activeAnalysis: FieldAnalysis? {
            switch selectedScenario {
            case .gentleSouthFacingSlopes: gentleSouthFacingSlopesAnalysis
            case .steepWestAndNorthFacingSlopes: steepWestAndNorthFacingSlopesAnalysis
            }
        }
        
        func setUp() async throws -> Viewpoint {
            isUpdatingAnalysis = true
            defer { isUpdatingAnalysis = false }
            
            // Project the Web Mercator raster into UTM30N because slope and aspect require a conformal projection.
            let elevationField = try await ContinuousField.field(
                fromFilesAt: [try .terrainSuitabilityArranElevation()],
                bandIndex: 0,
                spatialReference: Self.utm30N
            )
            let elevationFunction = ContinuousFieldFunction.function(withResult: elevationField)
            let inputs = TerrainAnalysisInputs(
                slopeFunction: elevationFunction.slope(),
                aspectFunction: elevationFunction.aspect(),
                elevationFunction: elevationFunction,
                aboveSeaLevelSelection: elevationFunction.isGreaterThanOrEqualTo(0)
            )
            
            let gentleAnalysis = makeAnalysis(
                inputs: inputs,
                criteria: .gentleSouthFacingSlopes,
                color: .systemGreen
            )
            let steepAnalysis = makeAnalysis(
                inputs: inputs,
                criteria: .steepWestAndNorthFacingSlopes,
                color: .systemPurple
            )
            gentleSouthFacingSlopesAnalysis = gentleAnalysis
            steepWestAndNorthFacingSlopesAnalysis = steepAnalysis
            analysisOverlay.addAnalyses([
                gentleAnalysis,
                steepAnalysis
            ])
            showAnalysis(for: selectedScenario)
            return Viewpoint(center: elevationField.extent.center, scale: 200_000)
        }
        
        func showAnalysis(for scenario: SiteScenario) {
            selectedScenario = scenario
            // Reset; MapView's analysis view state callback will set this to true while the active analysis is updating.
            isUpdatingAnalysis = false
            gentleSouthFacingSlopesAnalysis?.isVisible = scenario == .gentleSouthFacingSlopes
            steepWestAndNorthFacingSlopesAnalysis?.isVisible = scenario == .steepWestAndNorthFacingSlopes
        }
        
        private func makeAnalysis(inputs: TerrainAnalysisInputs, criteria: TerrainCriteria, color: UIColor) -> FieldAnalysis {
            // The long-form range methods and logicalAnd can be used instead of these operator overloads.
            let slopeRangeMask = (inputs.slopeFunction .>= criteria.slopeRange.lowerBound) .&
            (inputs.slopeFunction .<= criteria.slopeRange.upperBound)
            let elevationRangeMask = (inputs.elevationFunction .>= criteria.elevationRange.lowerBound) .&
            (inputs.elevationFunction .<= criteria.elevationRange.upperBound)
            let aspectRangeMask: BooleanFieldFunction = if criteria.aspectStart <= criteria.aspectEnd {
                (inputs.aspectFunction .>= criteria.aspectStart) .& (inputs.aspectFunction .<= criteria.aspectEnd)
            } else {
                ((inputs.aspectFunction .>= criteria.aspectStart) .& (inputs.aspectFunction .< 360)) .|
                ((inputs.aspectFunction .>= 0) .& (inputs.aspectFunction .<= criteria.aspectEnd))
            }
            let scenarioFunction = slopeRangeMask
                .logicalAnd(with: aspectRangeMask)
                .logicalAnd(with: elevationRangeMask)
                .mask(selection: inputs.aboveSeaLevelSelection)
                .toDiscreteFieldFunction()
            let analysis = FieldAnalysis(
                function: scenarioFunction,
                renderer: ColormapRenderer(colors: [.white, color])
            )
            analysis.isVisible = false
            return analysis
        }
    }
    
    struct TerrainSuitabilitySettings: View {
        @Binding var selectedScenario: SiteScenario
        
        var body: some View {
            NavigationStack {
                Form {
                    Picker("", selection: $selectedScenario) {
                        ForEach(SiteScenario.allCases) { scenario in
                            Text(scenario.title).tag(scenario)
                        }
                    }
                    .pickerStyle(.inline)
                }
                .navigationTitle("Terrain Suitability")
            }
        }
    }
    
    enum SiteScenario: CaseIterable, Identifiable {
        case gentleSouthFacingSlopes
        case steepWestAndNorthFacingSlopes
        
        var id: Self { self }
        var title: String {
            switch self {
            case .gentleSouthFacingSlopes: "Gentle, lowland south-facing slopes"
            case .steepWestAndNorthFacingSlopes: "Steep, upland west- through north-facing slopes"
            }
        }
        var description: String {
            switch self {
            case .gentleSouthFacingSlopes: "Finds sheltered, lowland terrain with gentle south-facing slopes."
            case .steepWestAndNorthFacingSlopes: "Finds exposed, upland terrain with steep west- through north-facing slopes."
            }
        }
    }
}

private struct TerrainAnalysisInputs {
    let slopeFunction: ContinuousFieldFunction
    let aspectFunction: ContinuousFieldFunction
    let elevationFunction: ContinuousFieldFunction
    let aboveSeaLevelSelection: BooleanFieldFunction
}

private struct TerrainCriteria {
    let slopeRange: ClosedRange<Float>
    let aspectStart: Float
    let aspectEnd: Float
    let elevationRange: ClosedRange<Float>

    static let gentleSouthFacingSlopes = TerrainCriteria(slopeRange: 0...20, aspectStart: 112.5, aspectEnd: 247.5, elevationRange: 0...300)
    static let steepWestAndNorthFacingSlopes = TerrainCriteria(slopeRange: 20...80, aspectStart: 202.5, aspectEnd: 67.5, elevationRange: 300...850)
}
