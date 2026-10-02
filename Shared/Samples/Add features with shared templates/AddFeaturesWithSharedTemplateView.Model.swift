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
import Observation

extension AddFeaturesWithSharedTemplateView {
    /// The view model for the sample.
    @MainActor
    @Observable
    final class Model {
        /// A shared template and the ID of its target layer.
        struct TemplateItem: Identifiable {
            /// A unique identifier for the item.
            let id = UUID()
            /// The shared template represented by the item.
            let template: SharedTemplate
            /// The ID of a layer referenced by the template.
            let layerID: Int
        }

        /// The current stage or outcome of the shared template workflow.
        enum WorkflowState {
            case creatingFeatures
            case creationFailed
            case drawingCanceled
            case drawingLine
            case drawingPoint
            case editsSaved
            case editsUndone
            case featuresAdded
            case invalidGeometry
            case loading
            case loadingFailed
            case ready
            case savingEdits
            case savingFailed
            case undoFailed
            case undoingEdits
        }
        
        /// The Parks and Grounds Assets web map whose feature layers provide
        /// the shared templates used to create features in this sample.
        let map = Map(
            item: PortalItem(
                portal: .arcGISOnline(connection: .anonymous),
                id: PortalItem.ID("b635be46dfb545b888077389ac7f0962")!
            )
        )
        
        /// The geometry editor used to place a shared template's base geometry.
        let geometryEditor = GeometryEditor()
        
        /// The shared templates displayed in the template picker.
        private(set) var templateItems: [TemplateItem] = []
        
        /// The template currently being used to create features.
        private(set) var activeTemplateItem: TemplateItem?
        
        /// Whether the geodatabase has edits to save or undo.
        private(set) var hasPendingEdits = false
        
        /// The current workflow state, interpreted by the view.
        private(set) var state: WorkflowState = .loading {
            didSet {
                stateResetID = nil
            }
        }
        
        /// Identifies a pending transition from canceled drawing to ready.
        private(set) var stateResetID: UUID?
        
        /// Whether an asynchronous operation is in progress.
        private(set) var operationIsInProgress = false
        
        /// The service geodatabase that provides the shared templates.
        private var serviceGeodatabase: ServiceGeodatabase?
        
        /// Loads the map and its available preset and group shared templates.
        func setUp() async throws {
            guard state == .loading || state == .loadingFailed else { return }
            
            state = .loading
            operationIsInProgress = true
            defer { operationIsInProgress = false }
            
            do {
                try await map.load()
                
                // Get the first service geodatabase from the feature layers.
                guard let featureLayer = map.operationalLayers.first(where: { $0 is FeatureLayer }) as! FeatureLayer?,
                      let featureTable = featureLayer.featureTable as? ServiceFeatureTable,
                      let serviceGeodatabase = featureTable.serviceGeodatabase else {
                    throw SampleError.sharedTemplateSourceNotFound
                }
                self.serviceGeodatabase = serviceGeodatabase
                
                let templatesByLayer = try await serviceGeodatabase
                    .querySharedTemplates()
                try Task.checkCancellation()
                templateItems = makeTemplateItems(
                    templatesByLayer: templatesByLayer
                )
                state = .ready
            } catch {
                state = .loadingFailed
                throw error
            }
        }

        /// Creates picker items for the first preset and group templates,
        /// visiting layers in ascending ID order.
        /// - Parameter templatesByLayer: The shared templates keyed by layer ID.
        /// - Returns: Picker items for the first available template of each supported kind,
        ///   including their layer IDs.
        private func makeTemplateItems(
            templatesByLayer: [Int: [SharedTemplate]]
        ) -> [TemplateItem] {
            var includedKinds: Set<SharedTemplate.Kind> = []
            var items: [TemplateItem] = []

            for (layerID, templates) in templatesByLayer.sorted(by: { $0.key < $1.key }) {
                for template in templates {
                    guard [.preset, .group].contains(template.kind),
                          !includedKinds.contains(template.kind) else {
                        continue
                    }
                    items.append(
                        TemplateItem(
                            template: template,
                            layerID: layerID
                        )
                    )
                    includedKinds.insert(template.kind)
                }

                if includedKinds.count == 2 { break }
            }
            return items
        }
        
        /// Starts drawing a geometry for a shared template.
        /// - Parameter item: The selected shared template item.
        func startDrawing(with item: TemplateItem) throws {
            guard !geometryEditor.isStarted else { return }
            
            guard let constructionTool = item.template.defaultConstructionTool(
                forLayerWithID: item.layerID
            ) else {
                throw SampleError.unsupportedConstructionTool
            }
            
            activeTemplateItem = item
            geometryEditor.tool = VertexTool()
            
            switch constructionTool.kind {
            case .point:
                state = .drawingPoint
                geometryEditor.start(withType: Point.self)
            case .line:
                state = .drawingLine
                geometryEditor.start(withType: Polyline.self)
            default:
                activeTemplateItem = nil
                throw SampleError.unsupportedConstructionTool
            }
        }
        
        /// Completes the drawing in the geometry editor and adds
        /// the features to the local service geodatabase.
        func completeDrawing() async throws {
            guard let activeTemplateItem,
                  let serviceGeodatabase else { return }
            guard geometryEditor.isStarted,
                  let geometry = geometryEditor.geometry,
                  geometry.sketchIsValid else {
                state = .invalidGeometry
                return
            }
            geometryEditor.stop()
            self.activeTemplateItem = nil

            operationIsInProgress = true
            state = .creatingFeatures
            defer {
                finishEditing()
                operationIsInProgress = false
            }

            do {
                let featureCreationSet = try await serviceGeodatabase
                    .makeFeatures(
                        sharedTemplate: activeTemplateItem.template,
                        geometry: geometry
                    )
                try Task.checkCancellation()
                try await serviceGeodatabase.addFeatures(
                    using: featureCreationSet
                )
                state = .featuresAdded
            } catch {
                state = .creationFailed
                throw error
            }
        }
        
        /// Stops drawing and resets the template picker.
        func cancelDrawing() {
            if geometryEditor.isStarted {
                geometryEditor.stop()
            }
            activeTemplateItem = nil
            state = .drawingCanceled
            stateResetID = UUID()
        }

        /// Returns to ready after two seconds unless the workflow changes.
        /// - Parameter id: The identifier of the pending state reset.
        func resetState(afterDelayFor id: UUID) async {
            do {
                try await Task.sleep(for: .seconds(2))
            } catch {
                return
            }
            guard !Task.isCancelled, stateResetID == id else { return }
            state = .ready
        }
        
        /// Applies the local edits to the service.
        func saveEdits() async throws {
            guard let serviceGeodatabase else { return }

            operationIsInProgress = true
            state = .savingEdits
            defer {
                finishEditing()
                operationIsInProgress = false
            }

            do {
                let editResults = try await serviceGeodatabase.applyEdits()
                state = if editResults.allSatisfy({
                    $0.editResults.allSatisfy { !$0.didCompleteWithErrors }
                }) {
                    .editsSaved
                } else {
                    .savingFailed
                }
            } catch {
                state = .savingFailed
                throw error
            }
        }
        
        /// Discards all local edits in the service geodatabase.
        func undoEdits() async throws {
            guard let serviceGeodatabase else { return }

            operationIsInProgress = true
            state = .undoingEdits
            defer {
                finishEditing()
                operationIsInProgress = false
            }

            do {
                try await serviceGeodatabase.undoLocalEdits()
                state = .editsUndone
            } catch {
                state = .undoFailed
                throw error
            }
        }
        
        /// Reconciles state after an editing operation, even if it failed or was canceled.
        private func finishEditing() {
            hasPendingEdits = serviceGeodatabase?.hasLocalEdits ?? false
            activeTemplateItem = nil
        }
    }
}

extension AddFeaturesWithSharedTemplateView.Model {
    /// An error associated with the shared template workflow.
    enum SampleError: Error {
        case sharedTemplateSourceNotFound
        case unsupportedConstructionTool
    }
}
