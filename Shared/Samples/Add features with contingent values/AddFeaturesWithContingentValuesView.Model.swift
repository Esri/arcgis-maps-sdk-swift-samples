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

extension AddFeaturesWithContingentValuesView {
    /// The view model for the sample.
    @MainActor
    class Model: ObservableObject {
        // MARK: Properties
        
        /// A map with a topographic vector titled basemap of the Fillmore, CA, USA area.
        let map: Map = {
            // Create a vector tiled layer using a local URL.
            let fillmoreVectorTiledLayer = ArcGISVectorTiledLayer(url: .fillmoreTopographicMap)
            
            // Create a map using the vector tiled layer as a basemap.
            let fillmoreBasemap = Basemap(baseLayer: fillmoreVectorTiledLayer)
            let map = Map(basemap: fillmoreBasemap)
            
            return map
        }()
        
        /// The graphics overlay for the buffer graphics.
        let graphicsOverlay: GraphicsOverlay = {
            let graphicsOverlay = GraphicsOverlay()
            
            // Create a simple renderer for the buffer graphics.
            let bufferPolygonOutlineSymbol = SimpleLineSymbol(style: .solid, color: .black, width: 2)
            let bufferPolygonFillSymbol = SimpleFillSymbol(
                style: .forwardDiagonal,
                color: .red,
                outline: bufferPolygonOutlineSymbol
            )
            graphicsOverlay.renderer = SimpleRenderer(symbol: bufferPolygonFillSymbol)
            
            return graphicsOverlay
        }()
        
        /// A temporary file containing a geodatabase copied from a local URL.
        private let geodatabaseFile = GeodatabaseFile(fileURL: .contingentValuesBirdNests)
        
        /// The feature table containing the features.
        private var featureTable: ArcGISFeatureTable?
        
        /// The feature in the feature table.
        private(set) var feature: ArcGISFeature?
        
        /// A Boolean value indicating whether all the contingency constraints associated with the feature are valid.
        @Published private(set) var contingenciesAreValid = false
        
        // MARK: Methods
        
        /// Loads the features from the geodatabase.
        func loadFeatures() async throws {
            // Get the feature table from the geodatabase.
            try await geodatabaseFile?.geodatabase.load()
            guard let featureTable = geodatabaseFile?.geodatabase.featureTables.first else { return }
            self.featureTable = featureTable
            
            // Load the feature table's contingent values definition.
            try await featureTable.contingentValuesDefinition.load()
            
            // Create a feature layer from the table and add it to the map.
            let featureLayer = FeatureLayer(featureTable: featureTable)
            map.addOperationalLayer(featureLayer)
            
            // Create graphics for the features' buffers and add them to the graphics overlay.
            let bufferGraphics = try await bufferGraphics(for: featureTable)
            graphicsOverlay.addGraphics(bufferGraphics)
        }
        
        /// Adds a feature representing a bird's nest to the map at a given point.
        /// - Parameter mapPoint: The point on the map.
        func addFeature(at mapPoint: Point) async throws {
            // Make a feature using the feature table.
            guard let newFeature = featureTable?.makeFeature(geometry: mapPoint) as? ArcGISFeature
            else { return }
            
            // Add the feature to the feature table.
            try await featureTable?.add(newFeature)
            feature = newFeature
            
            // Create an initial graphic for the buffer and add it to the graphics overlay.
            graphicsOverlay.addGraphic(Graphic())
        }
        
        /// Removes the added feature from the map.
        func removeFeature() async throws {
            // Remove the feature from the feature table.
            if let feature {
                try await featureTable?.delete(feature)
                self.feature = nil
            }
            
            // Remove the feature's buffer graphic from the graphics overlay.
            if let lastGraphic = graphicsOverlay.graphics.last {
                graphicsOverlay.removeGraphic(lastGraphic)
            }
            
            contingenciesAreValid = false
        }
        
        /// Sets an attribute on the feature to a given value.
        /// - Parameters:
        ///   - value: The value.
        ///   - key: The key associated with the attribute.
        func setFeatureAttributeValue(_ value: Any?, forKey key: String) {
            guard let featureTable, let feature else { return }
            
            // Update the feature's attribute.
            feature.setAttributeValue(value, forKey: key)
            
            // Validate the feature's contingencies.
            let contingencyViolations = featureTable.validateContingencyConstraints(for: feature)
            contingenciesAreValid = contingencyViolations.isEmpty
            
            // Update the buffer graphic when needed.
            guard key == "BufferSize" else { return }
            graphicsOverlay.graphics.last?.geometry = bufferPolygon(for: feature)
        }
        
        /// The coded values for the status field from the feature table.
        /// - Returns: The coded values.
        func statusCodedValues() -> [CodedValue] {
            // Get the status field from the feature table.
            let statusField = featureTable?.field(named: "Status")
            
            // Get the domain from the field.
            guard let codedValueDomain = statusField?.domain as? CodedValueDomain else { return [] }
            
            // Get the coded values from the domain.
            return codedValueDomain.codedValues
        }
        
        /// The contingent coded values for the feature and the protection field from the feature table.
        /// - Returns: The contingent coded values.
        func protectionContingentCodedValues() -> [ContingentCodedValue] {
            guard let feature else { return [] }
            
            // Get the contingent values result for the feature and protection field.
            let contingentValuesResult = featureTable?.contingentValues(
                with: feature,
                forFieldNamed: "Protection"
            )
            
            // Get contingent coded values for the protection field group.
            guard let protectionGroupContingentValues = contingentValuesResult?
                .contingentValuesByFieldGroup["ProtectionFieldGroup"] as? [ContingentCodedValue]
            else { return [] }
            
            return protectionGroupContingentValues
        }
        
        /// The buffer size range for the feature and buffer size field from the feature table.
        /// - Returns: A range made up from the contingent range value's min and max.
        func bufferSizeRange() -> ClosedRange<Double>? {
            guard let feature else { return nil }
            
            // Get the contingent values result for the feature and buffer size field.
            let contingentValuesResult = featureTable?.contingentValues(
                with: feature,
                forFieldNamed: "BufferSize"
            )
            
            // Get contingent range values for the buffer size field group.
            guard let bufferSizeGroupContingentValues = contingentValuesResult?
                .contingentValuesByFieldGroup["BufferSizeFieldGroup"] as? [ContingentRangeValue]
            else { return nil }
            
            // Create a range with min and max value from the contingent range value.
            guard let contingentRangeValue = bufferSizeGroupContingentValues.first,
                  let minValue = contingentRangeValue.minValue as? Int,
                  let maxValue = contingentRangeValue.maxValue as? Int
            else { return nil }
            
            return Double(minValue)...Double(maxValue)
        }
        
        /// The buffer graphics for the features in a given feature table.
        /// - Parameter featureTable: The feature table containing the features.
        private func bufferGraphics(
            for featureTable: GeodatabaseFeatureTable
        ) async throws -> [Graphic] {
            // Create the query parameters to filter for buffer sizes greater than 0.
            let queryParameters = QueryParameters()
            queryParameters.whereClause = "BufferSize > 0"
            
            // Query the features in the feature table using the query parameters.
            let queryResult = try await featureTable.queryFeatures(using: queryParameters)
            
            // Create graphics for the features in the query result.
            let bufferGraphics = queryResult.features().map { feature in
                let bufferPolygon = bufferPolygon(for: feature)
                return Graphic(geometry: bufferPolygon)
            }
            
            return bufferGraphics
        }
        
        /// A polygon created from a given feature's geometry and buffer size attribute.
        /// - Parameter feature: The feature.
        /// - Returns: A new `Polygon` object.
        private func bufferPolygon(for feature: Feature) -> ArcGIS.Polygon? {
            // Get the buffer size from the feature's attributes.
            guard let bufferSize = feature.attributes["BufferSize"] as? Int32,
                  let featureGeometry = feature.geometry
            else { return nil }
            
            // Create a polygon using the feature's geometry and buffer size.
            return GeometryEngine.buffer(around: featureGeometry, distance: Double(bufferSize))
        }
    }
}

private extension AddFeaturesWithContingentValuesView.Model {
    // MARK: GeodatabaseFile
    
    /// A temporary file containing a geodatabase copied from a given file URL.
    final class GeodatabaseFile {
        /// The geodatabase contained in the file.
        private(set) var geodatabase: Geodatabase
        
        init?(fileURL: URL) {
            do {
                // Create a temporary directory.
                let temporaryDirectoryURL = try FileManager.default.url(
                    for: .itemReplacementDirectory,
                    in: .userDomainMask,
                    appropriateFor: fileURL,
                    create: true
                )
                
                // Create a temporary URL where the geodatabase URL can be copied to.
                let temporaryGeodatabaseURL = temporaryDirectoryURL
                    .appendingPathComponent("ContingentValuesBirdNests", isDirectory: false)
                    .appendingPathExtension("geodatabase")
                
                // Copy the item to the temporary URL.
                try FileManager.default.copyItem(at: fileURL, to: temporaryGeodatabaseURL)
                
                // Create the geodatabase with the URL.
                geodatabase = Geodatabase(fileURL: temporaryGeodatabaseURL)
            } catch {
                return nil
            }
        }
        
        deinit {
            // Close the geodatabase
            geodatabase.close()
            
            // Remove the temporary file.
            try? FileManager.default.removeItem(at: geodatabase.fileURL)
            
            // Remove the temporary directory.
            let temporaryDirectoryURL = geodatabase.fileURL.deletingLastPathComponent()
            try? FileManager.default.removeItem(at: temporaryDirectoryURL)
        }
    }
}

private extension URL {
    /// A URL to the local "Contingent Values Bird Nests" geodatabase.
    static var contingentValuesBirdNests: URL {
        Bundle.main.url(forResource: "ContingentValuesBirdNests", withExtension: "geodatabase")!
    }
    
    /// A URL to the local "Fillmore Topographic Map" vector tile package.
    static var fillmoreTopographicMap: URL {
        Bundle.main.url(forResource: "FillmoreTopographicMap", withExtension: "vtpk")!
    }
}
