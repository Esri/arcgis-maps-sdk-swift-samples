// Copyright 2023 Esri
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
import Combine

extension CreateAndSaveKMLView {
    /// The model used to store the geo model and other expensive objects used in this view.
    @MainActor
    class Model: ObservableObject {
        /// A dark gray map.
        let map = Map(basemapStyle: .arcGISDarkGray)
        
        /// The geometry editor that deals with the sketching.
        let geometryEditor: GeometryEditor
        
        /// The KML style used for the geometry.
        var kmlStyle: KMLStyle?
        
        /// A KML document that serves as a container for features and styles.
        var kmlDocument = KMLDocument()
        
        /// A KMZ file that can be exported with the system's file exporter.
        var kmzFile = KMZFile(document: .init())
        
        /// A Boolean value indicating if the clear button is disabled.
        @Published private(set) var clearButtonIsDisabled = true
        
        /// A Boolean value indicating if the saved sketches can be cleared.
        @Published private(set) var canClearSavedSketches = false
        
        /// A Boolean value indicating if the geometry editor has started.
        @Published private(set) var isStarted = false
        
        /// A Boolean value indicating if the geometry can be saved to a graphics overlay.
        @Published private(set) var canSave = false
        
        /// The current geometry of the geometry editor.
        @Published var geometry: Geometry? {
            didSet {
                clearButtonIsDisabled = geometry.map(\.isEmpty) ?? true
                canSave = geometry?.sketchIsValid ?? false
            }
        }
        
        /// A Boolean value indicating if we should show the file exporter.
        @Published var showingFileExporter = false
        
        /// A Boolean value indicating if the file exporter button should be disabled.
        @Published var fileExporterButtonIsDisabled = true
        
        /// The error shown in the error alert.
        @Published var error: Error?
        
        /// Creates the model for this view.
        init() {
            self.geometryEditor = GeometryEditor()
            
            resetKMLLayer()
        }
        
        /// Clears all the saved sketches on the graphics overlay.
        func clearSavedSketches() {
            canClearSavedSketches = false
            fileExporterButtonIsDisabled = true
            map.removeAllOperationalLayers()
            resetKMLLayer()
        }
        
        /// Stops editing with the geometry editor.
        func stop() {
            geometryEditor.stop()
            isStarted = false
            kmlStyle = nil
        }
        
        /// Saves the current geometry to the graphics overlay and stops editing.
        /// - Precondition: `canSave`
        func save() {
            precondition(canSave)
            let geometry = geometryEditor.geometry!
            let projectedGeometry = GeometryEngine.project(geometry, into: .wgs84)!
            
            let kmlGeometry = KMLGeometry(geometry: projectedGeometry, altitudeMode: .clampToGround)!
            let currentPlacemark = KMLPlacemark(geometry: kmlGeometry)
            currentPlacemark.style = kmlStyle
            kmlDocument.addChildNode(currentPlacemark)
            
            stop()
            canClearSavedSketches = true
            fileExporterButtonIsDisabled = false
            
            Task {
                try? await kmzFile.saveFile()
            }
        }
        
        /// Resets the KML Layer that is used on the map.
        func resetKMLLayer() {
            kmlDocument = KMLDocument()
            kmzFile = KMZFile(document: kmlDocument)
            let kmlDataset = KMLDataset(rootNode: kmlDocument)
            map.addOperationalLayer(KMLLayer(dataset: kmlDataset))
        }
        
        /// Starts the geometry editor with a geometry type.
        /// - Parameter geometryType: The geometry type used to start the geometry editor.
        func startGeometryEditor(withType geometryType: Geometry.Type) {
            geometryEditor.tool = VertexTool()
            geometryEditor.start(withType: geometryType)
            isStarted = true
        }
    }
}
