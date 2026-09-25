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

extension AddFeaturesWithSharedTemplateView {
    /// The view model for the sample.
    @MainActor
    @Observable
    final class Model {
        /// A displayable shared template and the ID of its target layer.
        struct TemplateItem: Identifiable {
            /// A unique identifier for the item.
            let id = UUID()
            /// The shared template represented by the item.
            let template: SharedTemplate
            /// The ID of a layer referenced by the template.
            let layerID: Int
            /// The swatch displayed for the template.
            let swatch: UIImage

            /// A user-friendly name for the template kind.
            var kindLabel: String {
                switch template.kind {
                case .feature: "Feature"
                case .group: "Group"
                case .preset: "Preset"
                @unknown default: "Unknown"
                }
            }
        }
        
        /// The map containing service-backed layers with shared templates.
        let map = Map(
            item: PortalItem(
                portal: .arcGISOnline(connection: .anonymous),
                id: .parksAndGroundsAssets
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
        
        /// The instructions displayed to the user.
        private(set) var status = "Loading shared templates…"
        
        /// Whether an asynchronous operation is in progress.
        private(set) var operationIsInProgress = false
        
        /// The service geodatabase that provides the shared templates.
        private var serviceGeodatabase: ServiceGeodatabase?
        
        /// Loads the map and its available preset and group shared templates.
        func loadSharedTemplates() async throws {
            guard templateItems.isEmpty else { return }
            
            operationIsInProgress = true
            defer { operationIsInProgress = false }
            
            do {
                try await map.load()
                
                // Get the first service geodatabase from the feature layers.
                guard let serviceGeodatabase = map.operationalLayers
                    .compactMap({ $0 as? FeatureLayer })
                    .compactMap(\.featureTable)
                    .compactMap({ $0 as? ServiceFeatureTable })
                    .compactMap(\.serviceGeodatabase)
                    .first else {
                    throw SampleError.sharedTemplateSourceNotFound
                }
                self.serviceGeodatabase = serviceGeodatabase
                
                let templatesByLayer = try await serviceGeodatabase
                    .querySharedTemplates()
                let items = try await makeTemplateItems(from: templatesByLayer)
                
                guard !items.isEmpty else {
                    throw SampleError.supportedTemplateNotFound
                }
                templateItems = items
                status = Self.instruction
            } catch {
                status = "Unable to load templates."
                throw error
            }
        }

        /// Creates picker items for the first preset and group templates,
        /// visiting layers in ascending ID order.
        private func makeTemplateItems(
            from templatesByLayer: [Int: [SharedTemplate]]
        ) async throws -> [TemplateItem] {
            var includedKinds: Set<SharedTemplate.Kind> = []
            var items: [TemplateItem] = []

            for layerID in templatesByLayer.keys.sorted() {
                guard let templates = templatesByLayer[layerID] else {
                    continue
                }

                for template in templates {
                    guard [.preset, .group].contains(template.kind),
                          !includedKinds.contains(template.kind) else {
                        continue
                    }
                    try Task.checkCancellation()

                    // A missing swatch should not prevent template selection.
                    let swatch = (try? await template.makeSwatch(
                        layerID: layerID
                    )) ?? UIImage(systemName: "plus.square")!
                    // Do not treat task cancellation as a missing swatch.
                    try Task.checkCancellation()
                    items.append(
                        TemplateItem(
                            template: template,
                            layerID: layerID,
                            swatch: swatch
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
                status = "Place a point, then tap Complete or Cancel."
                geometryEditor.start(withType: Point.self)
            case .line:
                status = "Sketch a line, then tap Complete or Cancel."
                geometryEditor.start(withType: Polyline.self)
            default:
                activeTemplateItem = nil
                throw SampleError.unsupportedConstructionTool
            }
        }
        
        /// Completes the drawing in the geometry editor and adds 
        /// the feature to the local service geodatabase.
        func completeDrawing() async throws {
            guard let activeTemplateItem,
                  let serviceGeodatabase else { return }
            guard geometryEditor.isStarted,
                  let geometry = geometryEditor.geometry,
                  geometry.sketchIsValid else {
                status = "Draw a valid geometry, then tap Complete or Cancel."
                return
            }
            geometryEditor.stop()
            self.activeTemplateItem = nil

            operationIsInProgress = true
            status = "Creating features…"
            defer {
                updateAfterEditing(status: status)
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
                status = "Features added."
            } catch {
                status = "Unable to create or add features."
                throw error
            }
        }
        
        /// Stops drawing and resets the template picker.
        /// - Parameter status: The status to display after drawing stops.
        func cancelDrawing(status: String = "Draw canceled.") {
            if geometryEditor.isStarted {
                geometryEditor.stop()
            }
            activeTemplateItem = nil
            self.status = "\(status) \(Self.instruction)"
        }
        
        /// Applies the local edits to the service.
        func saveEdits() async throws {
            guard let serviceGeodatabase else { return }

            operationIsInProgress = true
            status = "Saving edits…"
            defer {
                updateAfterEditing(status: status)
                operationIsInProgress = false
            }

            do {
                let editResults = try await serviceGeodatabase.applyEdits()
                guard editResults.allSatisfy({
                    $0.editResults.allSatisfy { !$0.didCompleteWithErrors }
                }) else {
                    status = "Unable to save edits."
                    return
                }
                status = "Edits saved."
            } catch {
                status = "Unable to save edits."
                throw error
            }
        }
        
        /// Discards all local edits in the service geodatabase.
        func undoEdits() async throws {
            guard let serviceGeodatabase else { return }

            operationIsInProgress = true
            status = "Undoing local edits…"
            defer {
                updateAfterEditing(status: status)
                operationIsInProgress = false
            }

            do {
                try await serviceGeodatabase.undoLocalEdits()
                status = "Edits undone."
            } catch {
                status = "Unable to undo edits."
                throw error
            }
        }
        
        /// The instruction shown while the template picker is available.
        private static let instruction = """
            Open Shared Templates and select a template to create features.
            """
        
        /// Reconciles state after an editing operation, even if it failed or was canceled.
        private func updateAfterEditing(status: String) {
            hasPendingEdits = serviceGeodatabase?.hasLocalEdits ?? false
            activeTemplateItem = nil
            let instruction = hasPendingEdits ? "Save or undo edits." : Self.instruction
            self.status = "\(status) \(instruction)"
        }
    }
}

private extension PortalItem.ID {
    /// The ID of the Parks and Grounds Assets web map on ArcGIS Online.
    static var parksAndGroundsAssets: Self {
        .init("b635be46dfb545b888077389ac7f0962")!
    }
}

private extension AddFeaturesWithSharedTemplateView.Model {
    /// An error associated with the shared template workflow.
    enum SampleError: LocalizedError {
        case sharedTemplateSourceNotFound
        case supportedTemplateNotFound
        case unsupportedConstructionTool
        
        /// The user-facing explanation of the workflow error.
        var errorDescription: String? {
            switch self {
            case .sharedTemplateSourceNotFound:
                "The map does not contain a shared template source."
            case .supportedTemplateNotFound:
                "The map does not contain a preset or group shared template."
            case .unsupportedConstructionTool:
                """
                The template's default construction tool is not supported \
                by this sample.
                """
            }
        }
    }
}
