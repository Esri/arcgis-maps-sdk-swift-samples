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

/// Provides the types that support the terrain suitability sample.
extension AnalyzeTerrainSuitabilityFromSlopeAndAspectView {
    /// The model that creates and manages the terrain suitability analyses.
    @MainActor
    @Observable
    final class Model {
        /// The WGS 84 UTM zone 30N spatial reference used by the elevation data and map.
        private static let utm30N = SpatialReference(wkid: WKID(32630)!)!
       
        /// The map that displays the terrain suitability analyses.
        let map = Map(spatialReference: Model.utm30N)
        /// The overlay containing the terrain suitability analyses.
        let analysisOverlay = AnalysisOverlay()
        /// A Boolean value indicating whether an analysis is being updated.
        var isUpdatingAnalysis = false
        
        /// The analysis for gentle, lowland south-facing slopes.
        private var gentleSouthFacingSlopesAnalysis: FieldAnalysis?
        /// The analysis for steep, upland west- through north-facing slopes.
        private var steepWestAndNorthFacingSlopesAnalysis: FieldAnalysis?
        /// The scenario whose analysis is currently visible.
        var selectedScenario = SiteScenario.gentleSouthFacingSlopes {
            didSet {
                updateAnalysisVisibility()
            }
        }
        
        /// The analysis associated with the selected scenario, if it has been created.
        var activeAnalysis: FieldAnalysis? {
            switch selectedScenario {
            case .gentleSouthFacingSlopes: gentleSouthFacingSlopesAnalysis
            case .steepWestAndNorthFacingSlopes: steepWestAndNorthFacingSlopesAnalysis
            }
        }
        
        /// Creates the elevation field and terrain suitability analyses used by the sample.
        /// - Returns: A viewpoint centered on the extent of the elevation data.
        /// - Throws: An error if the elevation data cannot be accessed or used to create a field.
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
            updateAnalysisVisibility()
            return Viewpoint(center: elevationField.extent.center, scale: 200_000)
        }
        
        /// Updates the analyses so only the selected scenario is visible.
        private func updateAnalysisVisibility() {
            // Reset; MapView's analysis view state callback will set this to true while the active analysis is updating.
            isUpdatingAnalysis = false
            gentleSouthFacingSlopesAnalysis?.isVisible = selectedScenario == .gentleSouthFacingSlopes
            steepWestAndNorthFacingSlopesAnalysis?.isVisible = selectedScenario == .steepWestAndNorthFacingSlopes
        }
        
        /// Creates a field analysis that identifies cells matching a set of terrain criteria.
        /// - Parameters:
        ///   - inputs: The elevation-derived field functions used to evaluate each cell.
        ///   - criteria: The slope, aspect, and elevation ranges that define suitable terrain.
        ///   - color: The color used to render cells that satisfy all criteria.
        /// - Returns: A hidden field analysis configured with the suitability function and renderer.
        private func makeAnalysis(inputs: TerrainAnalysisInputs, criteria: TerrainCriteria, color: UIColor) -> FieldAnalysis {
            // Create Boolean masks that select cells within the inclusive slope and elevation ranges.
            // The long-form comparison methods can be used instead of these operator overloads.
            let slopeRangeMask = (inputs.slopeFunction .>= criteria.slopeRange.lowerBound) .&
            (inputs.slopeFunction .<= criteria.slopeRange.upperBound)
            let elevationRangeMask = (inputs.elevationFunction .>= criteria.elevationRange.lowerBound) .&
            (inputs.elevationFunction .<= criteria.elevationRange.upperBound)
            
            let aspectRangeMask = makeAspectRangeMask(
                aspectFunction: inputs.aspectFunction,
                start: criteria.aspectStart,
                end: criteria.aspectEnd
            )
            
            // Intersect the masks so a cell is suitable only when it meets every criterion. Remove
            // cells below sea level, then convert the Boolean result to discrete values for rendering.
            let scenarioFunction = slopeRangeMask
                .logicalAnd(with: aspectRangeMask)
                .logicalAnd(with: elevationRangeMask)
                .mask(selection: inputs.aboveSeaLevelSelection)
                .toDiscreteFieldFunction()
            
            // Render false cells in white and suitable cells in the scenario's color. The analysis
            // starts hidden because updateAnalysisVisibility() controls which scenario is displayed.
            let analysis = FieldAnalysis(
                function: scenarioFunction,
                renderer: ColormapRenderer(colors: [.white, color])
            )
            analysis.isVisible = false
            return analysis
        }
        
        /// Creates a Boolean mask that selects cells within an aspect range.
        /// - Parameters:
        ///   - aspectFunction: A function that calculates aspect values in degrees clockwise from north.
        ///   - start: The clockwise starting angle of the aspect range.
        ///   - end: The clockwise ending angle of the aspect range.
        /// - Returns: A Boolean function that selects cells within the aspect range.
        private func makeAspectRangeMask(
            aspectFunction: ContinuousFieldFunction,
            start: Float,
            end: Float
        ) -> BooleanFieldFunction {
            if start <= end {
                (aspectFunction .>= start) .& (aspectFunction .<= end)
            } else {
                // A range whose start is greater than its end crosses north, so join the
                // selections on either side of 0 degrees.
                ((aspectFunction .>= start) .& (aspectFunction .< 360)) .|
                ((aspectFunction .>= 0) .& (aspectFunction .<= end))
            }
        }
    }
    
    /// A predefined combination of slope, aspect, and elevation criteria.
    enum SiteScenario: CaseIterable, Identifiable {
        /// Gentle south-facing slopes at low elevations.
        case gentleSouthFacingSlopes
        /// Steep west- through north-facing slopes at high elevations.
        case steepWestAndNorthFacingSlopes
        
        /// The scenario's stable identity.
        var id: Self { self }
        /// A concise label describing the scenario.
        var label: String {
            switch self {
            case .gentleSouthFacingSlopes: "Gentle, lowland south-facing slopes"
            case .steepWestAndNorthFacingSlopes: "Steep, upland west- through north-facing slopes"
            }
        }
        /// A description of the terrain found by the scenario.
        var description: String {
            switch self {
            case .gentleSouthFacingSlopes: "Finds sheltered, lowland terrain with gentle south-facing slopes."
            case .steepWestAndNorthFacingSlopes: "Finds exposed, upland terrain with steep west- through north-facing slopes."
            }
        }
    }
}

/// The field functions used to evaluate terrain suitability.
private struct TerrainAnalysisInputs {
    /// A function that calculates slope from the elevation field.
    let slopeFunction: ContinuousFieldFunction
    /// A function that calculates aspect from the elevation field.
    let aspectFunction: ContinuousFieldFunction
    /// A function that supplies elevation values.
    let elevationFunction: ContinuousFieldFunction
    /// A Boolean function that selects cells at or above sea level.
    let aboveSeaLevelSelection: BooleanFieldFunction
}

/// The value ranges that define suitable terrain for a scenario.
private struct TerrainCriteria {
    /// The inclusive range of suitable slope angles, in degrees.
    let slopeRange: ClosedRange<Float>
    /// The clockwise starting angle of the suitable aspect range, in degrees from north.
    let aspectStart: Float
    /// The clockwise ending angle of the suitable aspect range, in degrees from north.
    let aspectEnd: Float
    /// The inclusive range of suitable elevations, in meters.
    let elevationRange: ClosedRange<Float>
    
    /// The criteria for gentle, lowland south-facing slopes.
    static let gentleSouthFacingSlopes = TerrainCriteria(slopeRange: 0...20, aspectStart: 112.5, aspectEnd: 247.5, elevationRange: 0...300)
    /// The criteria for steep, upland west- through north-facing slopes.
    static let steepWestAndNorthFacingSlopes = TerrainCriteria(slopeRange: 20...80, aspectStart: 247.5, aspectEnd: 67.5, elevationRange: 300...850)
}

/// Provides access to the local raster data used by the terrain suitability analysis.
private extension URL {
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
