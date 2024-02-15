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

extension ListSpatialReferenceTransformationsView {
    /// The view model for the sample.
    class Model: ObservableObject {
        // MARK: Properties
        
        /// A map with a light grey basemap centered on Royal Observatory, Greenwich, UK.
        let map: Map = {
            let map = Map(basemapStyle: .arcGISLightGray)
            map.initialViewpoint = Viewpoint(center: .originalGeometry, scale: 5e3)
            return map
        }()
        
        /// The graphics overlay containing the graphics for the geometries.
        let graphicsOverlay: GraphicsOverlay = {
            // Create a red square graphic for the original geometry.
            let redSquareSymbol = SimpleMarkerSymbol(style: .square, color: .red, size: 20)
            let originalGraphic = Graphic(geometry: .originalGeometry, symbol: redSquareSymbol)
            
            // Create a blue cross graphic for the projected geometry.
            let blueCrossSymbol = SimpleMarkerSymbol(style: .cross, color: .blue, size: 20)
            let projectedGraphic = Graphic(symbol: blueCrossSymbol)
            
            return GraphicsOverlay(graphics: [originalGraphic, projectedGraphic])
        }()
        
        /// The geometry of the projected graphic, i.e., the last graphic in the graphics overlay.
        private var projectedGeometry: Geometry? {
            get { graphicsOverlay.graphics.last!.geometry }
            set { graphicsOverlay.graphics.last!.geometry = newValue }
        }
        
        /// The list of transformations suitable for projecting between the original geometry's and the map's spatial references.
        @Published private(set) var transformations: [GeographicTransformation] = []
        
        /// The transformation selected by the user.
        @Published private(set) var selectedTransformation: GeographicTransformation?
        
        // MARK: Methods
        
        /// Selects a given transformation and projects the geometry accordingly.
        /// - Parameter transformation: The transformation.
        func selectTransformation(_ transformation: GeographicTransformation) {
            // Project the original geometry using the transformation.
            let outputSpatialReference = map.spatialReference!
            
            projectedGeometry = GeometryEngine.project(
                .originalGeometry,
                into: outputSpatialReference,
                datumTransformation: transformation
            )
            selectedTransformation = transformation
        }
        
        /// Removes the current transformation selection and projection graphic.
        func removeSelection() {
            selectedTransformation = nil
            projectedGeometry = nil
        }
        
        /// The list of Projection Engine files that are missing from the local file system for a given transformation.
        /// - Parameter transformation: The transformation.
        /// - Returns: The filenames.
        func missingProjectionEngineFilenames(
            for transformation: GeographicTransformation
        ) -> [String] {
            // Get the missing projection engine filenames for each step.
            let missingFilenames = transformation.steps.compactMap { step in
                step.isMissingProjectionEngineFiles
                ? step.projectionEngineFilenames.joined(separator: ", ")
                : nil
            }
            
            return missingFilenames
        }
        
        /// Updates the transformations list using the transformation catalog.
        /// - Parameter extent: The bounding box of coordinates to be transformed.
        func updateTransformationsList(withExtent extent: Envelope? = nil) {
            // Get the input and output spatial references.
            let inputSpatialReference = Geometry.originalGeometry.spatialReference!
            let outputSpatialReference = map.spatialReference!
            
            // Get the transformations from the transformation catalog.
            transformations = TransformationCatalog.transformations(
                from: inputSpatialReference,
                to: outputSpatialReference,
                areaOfInterest: extent,
                ignoreVertical: true
            ) as! [GeographicTransformation]
            
            // Remove the selection if it is not in the new list.
            guard let selectedTransformation,
                  !transformations.contains(selectedTransformation) else { return }
            
            removeSelection()
        }
        
        /// Sets the URL to the directory of the Projection Engine files to be used by the transformation catalog.
        /// - Parameter url: The path to the directory.
        func setProjectionEngineDataURL(_ url: URL) throws {
            // Start accessing the URL.
            guard url.startAccessingSecurityScopedResource() else { return }
            
            // Stop accessing the last URL.
            TransformationCatalog.projectionEngineDirectoryURL?.stopAccessingSecurityScopedResource()
            
            // Set the transformation catalog's projection engine directory URL.
            // Normally, this method would be called immediately upon application startup before any
            // other API method calls, but for the purposes of this sample, it is being called here.
            try TransformationCatalog.setProjectionEngineDirectoryURL(url)
            
            // Update the transformations list.
            removeSelection()
            updateTransformationsList()
        }
    }
}

private extension Geometry {
    /// The starting point for the spatial reference projections.
    static var originalGeometry: Point {
        Point(x: 538_985, y: 177_329, spatialReference: .init(wkid: WKID(27700)!))
    }
}
