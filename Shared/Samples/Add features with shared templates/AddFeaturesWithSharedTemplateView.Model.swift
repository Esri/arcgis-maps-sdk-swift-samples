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

extension AddFeaturesWithSharedTemplateView {
    /// The view model for the sample.
    @MainActor
    final class Model: ObservableObject {
        /// A displayable shared template and the ID of the layer it creates features for.
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
            let kindName: String
        }
        
        /// The map containing a service-backed feature layer with shared templates.
        let map = Map(
            item: PortalItem(
                portal: .arcGISOnline(connection: .anonymous),
                id: PortalItem.ID("b635be46dfb545b888077389ac7f0962")!
            )
        )
        
        /// The geometry editor used to place the base geometry for a shared template.
        let geometryEditor = GeometryEditor()
        
        /// The shared templates displayed in the template picker.
        @Published private(set) var templateItems: [TemplateItem] = []
        
        /// The template currently being used to create features.
        @Published private(set) var activeTemplateItem: TemplateItem?
        
        /// A Boolean value indicating whether the geodatabase has edits to save or undo.
        @Published private(set) var hasPendingEdits = false
        
        /// The instructions displayed to the user.
        @Published private(set) var status = "Loading shared templates…"
        
        /// A Boolean value indicating whether an asynchronous operation is in progress.
        @Published private(set) var isBusy = false
        
        /// The service geodatabase that provides the shared templates.
        private var serviceGeodatabase: ServiceGeodatabase?
        
        /// Loads the map and creates items for one preset and one group template.
        /// - Parameter displayScale: The display scale used to create template swatches.
        func setUp(displayScale: CGFloat) async throws {
            guard templateItems.isEmpty else { return }
            
            isBusy = true
            defer { isBusy = false }
            
            do {
                try await map.load()
                
                guard let serviceGeodatabase = map.operationalLayers
                    .compactMap({ $0 as? FeatureLayer })
                    .compactMap(\.featureTable)
                    .compactMap({ $0 as? ServiceFeatureTable })
                    .compactMap(\.serviceGeodatabase)
                    .first else {
                    throw SampleError.sharedTemplateSourceNotFound
                }
                self.serviceGeodatabase = serviceGeodatabase
                
                let templatesByLayer = try await serviceGeodatabase.querySharedTemplates()
                var includedKinds: Set<SharedTemplate.Kind> = []
                var items: [TemplateItem] = []
                
                for layerID in templatesByLayer.keys.sorted() {
                    guard let templates = templatesByLayer[layerID] else { continue }
                    
                    for template in templates
                    where [.preset, .group].contains(template.kind) && !includedKinds.contains(template.kind) {
                        let swatch = (try? await template.makeSwatch(layerID: layerID))
                            ?? UIImage(systemName: "plus.square")!
                        items.append(
                            TemplateItem(
                                template: template,
                                layerID: layerID,
                                swatch: swatch.withConfiguration(
                                    UIImage.SymbolConfiguration(scale: displayScale >= 2 ? .large : .medium)
                                ),
                                kindName: template.kind == .preset ? "Preset" : "Group"
                            )
                        )
                        includedKinds.insert(template.kind)
                    }
                    
                    if includedKinds.count == 2 { break }
                }
                
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
        
        /// Creates features from the geometry and adds them to the service geodatabase locally.
        func completeDrawing() async throws {
            guard let activeTemplateItem,
                  let serviceGeodatabase,
                  let geometry = geometryEditor.stop(),
                  geometry.sketchIsValid else {
                cancelDrawing(status: "No valid geometry was drawn.")
                return
            }
            
            isBusy = true
            status = "Creating features…"
            defer { isBusy = false }
            
            do {
                let featureCreationSet = try await serviceGeodatabase.makeFeatures(
                    sharedTemplate: activeTemplateItem.template,
                    geometry: geometry
                )
                try await serviceGeodatabase.addFeatures(using: featureCreationSet)
                hasPendingEdits = serviceGeodatabase.hasLocalEdits
                status = "Save or undo edits."
            } catch {
                self.activeTemplateItem = nil
                status = "Unable to create or add features. \(Self.instruction)"
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
            
            isBusy = true
            status = "Saving edits…"
            defer { isBusy = false }
            
            do {
                _ = try await serviceGeodatabase.applyEdits()
                resetAfterEditing(status: "Edits saved.")
            } catch {
                status = "Unable to save edits."
                throw error
            }
        }
        
        /// Discards all local edits in the service geodatabase.
        func undoEdits() async throws {
            guard let serviceGeodatabase else { return }
            
            isBusy = true
            status = "Undoing local edits…"
            defer { isBusy = false }
            
            do {
                try await serviceGeodatabase.undoLocalEdits()
                resetAfterEditing(status: "Edits undone.")
            } catch {
                status = "Unable to undo edits."
                throw error
            }
        }
        
        /// The instruction shown while the template picker is available.
        private static let instruction = "Tap a shared template to create features."
        
        /// Resets state after pending edits are saved or undone.
        private func resetAfterEditing(status: String) {
            hasPendingEdits = false
            activeTemplateItem = nil
            self.status = "\(status) \(Self.instruction)"
        }
    }
}

private extension AddFeaturesWithSharedTemplateView.Model {
    /// An error associated with the shared template workflow.
    enum SampleError: LocalizedError {
        case sharedTemplateSourceNotFound
        case supportedTemplateNotFound
        case unsupportedConstructionTool
        
        var errorDescription: String? {
            switch self {
            case .sharedTemplateSourceNotFound:
                "The map does not contain a shared template source."
            case .supportedTemplateNotFound:
                "The map does not contain a preset or group shared template."
            case .unsupportedConstructionTool:
                "The template's default construction tool is not supported by this sample."
            }
        }
    }
}
