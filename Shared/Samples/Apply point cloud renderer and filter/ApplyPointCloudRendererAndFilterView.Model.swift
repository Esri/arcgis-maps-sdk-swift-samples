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
import Observation
import UIKit

extension ApplyPointCloudRendererAndFilterView {
    /// Stores the expensive GIS objects and updates them as settings change.
    @MainActor
    @Observable
    final class Model {
        /// The scene containing the point cloud layer.
        let scene: ArcGIS.Scene

        /// The Sonoma Area 1 LiDAR point cloud layer.
        let pointCloudLayer = PointCloudLayer(url: .sonomaPointCloud)

        /// The renderers, retained so switching does not construct replacements.
        private let renderers: [RendererKind: PointCloudRenderer]

        /// The selected renderer, initially RGB.
        var rendererKind = RendererKind.rgb {
            didSet {
                pointCloudLayer.renderer = renderers[rendererKind]
                updatePointSize()
            }
        }

        /// The scale factor applied to the active renderer's splat algorithm.
        var scaleFactor = 1.0 {
            didSet { updatePointSize() }
        }

        /// Whether selected classification codes are included or excluded.
        var classificationMode = PointCloudValueFilter.Mode.include {
            didSet { updateClassificationFilter() }
        }

        /// The classification codes selected by the user.
        private(set) var selectedClassifications: Set<Classification> = []

        /// The return types selected by the user.
        private(set) var selectedReturns: Set<PointCloudReturnFilter.ReturnType> = []

        /// The mutually exclusive requirements for scan direction flag bit 6.
        var scanDirection = ScanDirection.any {
            didSet { updateScanDirectionFilter() }
        }

        init() {
            renderers = Dictionary(uniqueKeysWithValues: RendererKind.allCases.map { kind in
                let renderer = kind.makeRenderer()
                renderer.pointsPerInch = 25
                renderer.sizeAlgorithm = PointCloudSplatAlgorithm(scaleFactor: 1)
                return (kind, renderer)
            })
            pointCloudLayer.renderer = renderers[.rgb]
            // No filters are added until the user interacts with a filter control.

            // Live point cloud filtering is supported only in a local scene view.
            scene = Scene(viewingMode: .local, basemapStyle: .arcGISImagery)
            scene.baseSurface.addElevationSource(ArcGISTiledElevationSource(url: .worldElevationService))
            scene.addOperationalLayer(pointCloudLayer)
            scene.initialViewpoint = Viewpoint(
                latitude: .nan,
                longitude: .nan,
                scale: .nan,
                camera: Camera(
                    latitude: 38.2324,
                    longitude: -122.636,
                    altitude: 350,
                    heading: 0,
                    pitch: 65,
                    roll: 0
                )
            )
        }

        /// Updates the existing size algorithm rather than replacing the renderer.
        private func updatePointSize() {
            let algorithm = pointCloudLayer.renderer?.sizeAlgorithm as? PointCloudSplatAlgorithm
            algorithm?.scaleFactor = scaleFactor
        }

        /// Updates a classification selection and applies its filter.
        func setClassification(_ classification: Classification, isSelected: Bool) {
            if isSelected {
                selectedClassifications.insert(classification)
            } else {
                selectedClassifications.remove(classification)
            }
            updateClassificationFilter()
        }

        /// Adds the classification filter on first use, then mutates that same filter.
        private func updateClassificationFilter() {
            let values = selectedClassifications.map { Double($0.rawValue) }.sorted()
            if let filter = pointCloudLayer.filters.first(where: { $0 is PointCloudValueFilter }) as? PointCloudValueFilter {
                filter.removeAllValues()
                filter.addValues(values)
                filter.mode = classificationMode
            } else {
                pointCloudLayer.addFilter(PointCloudValueFilter(
                    attributeName: "CLASS_CODE", values: values, mode: classificationMode
                ))
            }
        }

        /// Removes only the classification filter, preserving the other filters.
        func clearClassificationFilter() {
            if let filter = pointCloudLayer.filters.first(where: { $0 is PointCloudValueFilter }) {
                pointCloudLayer.removeFilter(filter)
            }
            selectedClassifications.removeAll()
        }

        /// Updates the included return types on the existing filter, or adds it on first use.
        func setReturnType(_ returnType: PointCloudReturnFilter.ReturnType, isSelected: Bool) {
            if isSelected {
                selectedReturns.insert(returnType)
            } else {
                selectedReturns.remove(returnType)
            }
            let includedReturns = PointCloudReturnFilter.ReturnType.options.filter { selectedReturns.contains($0) }
            if let filter = pointCloudLayer.filters.first(where: { $0 is PointCloudReturnFilter }) as? PointCloudReturnFilter {
                filter.removeAllIncludedReturns()
                filter.addIncludedReturns(includedReturns)
            } else {
                pointCloudLayer.addFilter(PointCloudReturnFilter(attributeName: "RETURNS", includedReturns: includedReturns))
            }
        }

        /// Removes only the return filter and resets its selections.
        func clearReturnFilter() {
            if let filter = pointCloudLayer.filters.first(where: { $0 is PointCloudReturnFilter }) {
                pointCloudLayer.removeFilter(filter)
            }
            selectedReturns.removeAll()
        }

        /// Updates the bitfield filter without requiring the same bit to be both set and clear.
        private func updateScanDirectionFilter() {
            let existingFilter = pointCloudLayer.filters.first(where: { $0 is PointCloudBitfieldFilter }) as? PointCloudBitfieldFilter
            guard scanDirection != .any else {
                if let existingFilter {
                    pointCloudLayer.removeFilter(existingFilter)
                }
                return
            }

            let filter: PointCloudBitfieldFilter
            if let existingFilter {
                filter = existingFilter
            } else {
                filter = PointCloudBitfieldFilter(attributeName: "FLAGS", requiredClearBits: [], requiredSetBits: [])
                pointCloudLayer.addFilter(filter)
            }
            filter.removeAllRequiredClearBits()
            filter.removeAllRequiredSetBits()
            // The collections contain zero-based bit positions, not bit masks.
            if scanDirection == .set {
                filter.addRequiredSetBit(6)
            } else {
                filter.addRequiredClearBit(6)
            }
        }
    }

    /// The available point cloud renderers.
    enum RendererKind: String, CaseIterable {
        case rgb = "RGB"
        case stretch = "Elevation Stretch"
        case classBreaks = "Elevation Class Breaks"
        case uniqueValue = "Classification"

        /// Creates a renderer using the attribute and colors appropriate to its type.
        func makeRenderer() -> PointCloudRenderer {
            switch self {
            case .rgb:
                return PointCloudRGBRenderer(attributeName: "RGB")
            case .stretch:
                return PointCloudStretchRenderer(attributeName: "ELEVATION", stops: [
                    PointCloudColorStop(color: UIColor(red: 31 / 255, green: 79 / 255, blue: 1, alpha: 1), value: 0),
                    PointCloudColorStop(color: UIColor(red: 33 / 255, green: 163 / 255, blue: 102 / 255, alpha: 1), value: 30),
                    PointCloudColorStop(color: UIColor(red: 229 / 255, green: 57 / 255, blue: 53 / 255, alpha: 1), value: 90)
                ])
            case .classBreaks:
                return PointCloudClassBreaksRenderer(attributeName: "ELEVATION", classBreaks: [
                    PointCloudColorClassBreak(color: UIColor(red: 96 / 255, green: 67 / 255, blue: 151 / 255, alpha: 1), minValue: 0, maxValue: 20),
                    PointCloudColorClassBreak(color: UIColor(red: 65 / 255, green: 145 / 255, blue: 136 / 255, alpha: 1), minValue: 20, maxValue: 40),
                    PointCloudColorClassBreak(color: UIColor(red: 216 / 255, green: 155 / 255, blue: 77 / 255, alpha: 1), minValue: 40, maxValue: Double(Float.greatestFiniteMagnitude))
                ])
            case .uniqueValue:
                // Colors for LAS classification codes 1 through 18, in code order.
                let colors: [UIColor] = [
                    UIColor(red: 139 / 255, green: 178 / 255, blue: 194 / 255, alpha: 1),
                    UIColor(red: 212 / 255, green: 223 / 255, blue: 160 / 255, alpha: 1),
                    UIColor(red: 168 / 255, green: 208 / 255, blue: 141 / 255, alpha: 1),
                    UIColor(red: 112 / 255, green: 173 / 255, blue: 71 / 255, alpha: 1),
                    UIColor(red: 47 / 255, green: 107 / 255, blue: 47 / 255, alpha: 1),
                    UIColor(red: 200 / 255, green: 62 / 255, blue: 62 / 255, alpha: 1),
                    UIColor(red: 187 / 255, green: 185 / 255, blue: 220 / 255, alpha: 1),
                    UIColor(red: 187 / 255, green: 225 / 255, blue: 228 / 255, alpha: 1),
                    UIColor(red: 155 / 255, green: 191 / 255, blue: 177 / 255, alpha: 1),
                    UIColor(red: 75 / 255, green: 85 / 255, blue: 99 / 255, alpha: 1),
                    UIColor(red: 107 / 255, green: 114 / 255, blue: 128 / 255, alpha: 1),
                    UIColor(red: 209 / 255, green: 213 / 255, blue: 219 / 255, alpha: 1),
                    UIColor(red: 245 / 255, green: 158 / 255, blue: 11 / 255, alpha: 1),
                    UIColor(red: 234 / 255, green: 179 / 255, blue: 8 / 255, alpha: 1),
                    UIColor(red: 124 / 255, green: 58 / 255, blue: 237 / 255, alpha: 1),
                    UIColor(red: 236 / 255, green: 72 / 255, blue: 153 / 255, alpha: 1),
                    UIColor(red: 139 / 255, green: 90 / 255, blue: 43 / 255, alpha: 1),
                    UIColor(red: 17 / 255, green: 24 / 255, blue: 39 / 255, alpha: 1)
                ]
                let uniqueValues = colors.enumerated().map { index, color in
                    PointCloudColorUniqueValue(color: color, values: [String(index + 1)])
                }
                return PointCloudUniqueValueRenderer(attributeName: "CLASS_CODE", uniqueValues: uniqueValues)
            }
        }
    }

    /// The LAS classification codes offered by the classification filter.
    enum Classification: Int, CaseIterable {
        case ground = 2
        case highVegetation = 5
        case building = 6

        var label: String {
            switch self {
            case .ground: "Ground"
            case .highVegetation: "High Vegetation"
            case .building: "Building"
            }
        }
    }

    /// The possible requirements for scan direction flag bit 6.
    enum ScanDirection: String, CaseIterable {
        case any = "Any"
        case set = "Required Set"
        case clear = "Required Clear"
    }
}

extension PointCloudReturnFilter.ReturnType {
    /// The return types in display order.
    static var options: [Self] { [.firstOfMany, .last, .lastOfMany, .single] }

    /// The user-facing name of the return type.
    var label: String {
        switch self {
        case .firstOfMany: "First of Many"
        case .last: "Last"
        case .lastOfMany: "Last of Many"
        case .single: "Single"
        @unknown default: "Unknown"
        }
    }
}

private extension URL {
    /// The URL of the Sonoma Area 1 LiDAR RGB scene layer.
    static var sonomaPointCloud: URL {
        URL(string: "https://tiles.arcgis.com/tiles/z2tnIkrLQ2BRzr6P/arcgis/rest/services/SONOMA_AREA1_LiDAR_RGB/SceneServer/layers/0")!
    }

    /// The URL of the World Elevation 3D terrain service.
    static var worldElevationService: URL {
        URL(string: "https://elevation3d.arcgis.com/arcgis/rest/services/WorldElevation3D/Terrain3D/ImageServer")!
    }
}
