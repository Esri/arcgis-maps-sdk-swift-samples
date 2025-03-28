// Copyright 2025 Esri
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
import Foundation

extension SnapGeometryEditsWithUtilityNetworkRulesView {
    /// The view model for the sample.
    @MainActor
    final class Model: ObservableObject {
        // MARK: Properties
        
        /// The utility element created from the selected feature.
        @Published private(set) var selectedElement: UtilityElement?
        
        /// The settings for the sources that the selected feature can be snapped to.
        @Published private(set) var snapSourceSettings: [SnapSourceSettings] = []
        
        /// A map with a streets night basemap initially centered on Naperville, IL, USA.
        let map: Map = {
            let map = Map(basemapStyle: .arcGISStreetsNight)
            
            let point = Point(x: -9811055.1560284, y: 5131792.195025, spatialReference: .webMercator)
            map.initialViewpoint = Viewpoint(center: point, scale: 1e4)
            
            // Enables full resolution to improve snapping accuracy.
            map.loadSettings.featureTilingMode = .enabledWithFullResolutionWhenSupported
            
            return map
        }()
        
        /// The graphics overlay containing an example graphic for snapping.
        let graphicsOverlay: GraphicsOverlay = {
            // Creates an example polyline graphic and adds it to the overlay.
            let polyline = try? Polyline.fromJSON(.polylineJSON)
            let graphic = Graphic(geometry: polyline)
            
            let graphicsOverlay = GraphicsOverlay(graphics: [graphic])
            graphicsOverlay.id = .graphics
            
            let dashedGrayLinkSymbol = SimpleLineSymbol(style: .dash, color: .gray, width: 3)
            graphicsOverlay.renderer = SimpleRenderer(symbol: dashedGrayLinkSymbol)
            
            return graphicsOverlay
        }()
        
        /// The editor for editing the selected feature's geometry.
        let geometryEditor: GeometryEditor = {
            let geometryEditor = GeometryEditor()
            geometryEditor.snapSettings.isEnabled = true
            return geometryEditor
        }()
        
        /// The tool for the geometry editor.
        private let vertexTool: GeometryEditorTool = {
#if targetEnvironment(macCatalyst)
            VertexTool()
#else
            ReticleVertexTool()
#endif
        }()
        
        /// The feature currently selected by the user.
        private var selectedFeature: ArcGISFeature?
        
        /// The snap sources and their renderers for resetting the sample.
        private var snapSourceRenderers: [(Renderable, Renderer?)] = []
        
        /// The geodatabase containing data for the Naperville gas utility network.
        private let geodatabase: Geodatabase = .napervilleGasUtilities()
        
        /// The geodatabase's utility network.
        private var utilityNetwork: UtilityNetwork {
            geodatabase.utilityNetworks.first!
        }
        
        // MARK: Methods
        
        deinit {
            geodatabase.close()
            
            let temporaryDirectoryURL = geodatabase.fileURL.deletingLastPathComponent()
            try? FileManager.default.removeItem(at: temporaryDirectoryURL)
        }
        
        /// Sets up the map and layers for the sample.
        func setUp() async throws {
            try await geodatabase.load()
            
            map.addUtilityNetwork(utilityNetwork)
            try await utilityNetwork.load()
            
            // Creates and adds subtype feature layers to the map.
            let lineLayer = SubtypeFeatureLayer(
                featureTable: geodatabase.featureTable(named: .pipelineLine)!
            )
            let deviceLayer = SubtypeFeatureLayer(
                featureTable: geodatabase.featureTable(named: "PipelineDevice")!
            )
            let junctionLayer = SubtypeFeatureLayer(
                featureTable: geodatabase.featureTable(named: "PipelineJunction")!
            )
            
            map.addOperationalLayers([lineLayer, deviceLayer, junctionLayer])
            await map.operationalLayers.load()
            
            // Turns off most of the subtype sublayers to reduce clutter on the map.
            let visibleSublayerNames: Set = [
                .distributionPipe,
                .servicePipe,
                "Excess Flow Valve",
                "Controllable Tee"
            ]
            for sublayer in lineLayer.subtypeSublayers + deviceLayer.subtypeSublayers {
                if !visibleSublayerNames.contains(sublayer.name) {
                    sublayer.isVisible = false
                }
            }
        }
        
        /// Selects a feature from a given list of identify layer results.
        /// - Parameter identifyResults: The identify layer results to get the feature from.
        func selectFeature(from identifyResults: [IdentifyLayerResult]) async throws {
            resetSelection()
            
            // Gets the first subtype feature with a point geometry.
            let sublayerGeoElement = identifyResults
                .flatMap { $0.sublayerResults.flatMap(\.geoElements) }
                .first(where: { $0 is ArcGISFeature && $0.geometry is Point })
            
            // Creates a utility element from the feature and uses it to set up the snap sources.
            if let feature = sublayerGeoElement as? ArcGISFeature,
               let featureLayer = feature.table?.layer as? FeatureLayer,
               let utilityElement = utilityNetwork.makeElement(arcGISFeature: feature) {
                selectedElement = utilityElement
                selectedFeature = feature
                featureLayer.selectFeature(feature)
                
                try await setUpSnapSourcesSettings(using: utilityElement.assetType)
            }
        }
        
        /// Clears the feature selection and resets the rendering.
        func resetSelection() {
            if let featureLayer = selectedFeature?.table?.layer as? FeatureLayer {
                featureLayer.clearSelection()
                featureLayer.resetFeaturesVisible()
            }
            
            selectedFeature = nil
            selectedElement = nil
            
            // Resets all the snap sources to use their default renderer.
            for (source, renderer) in snapSourceRenderers {
                source.renderer = renderer
            }
            snapSourceRenderers.removeAll(keepingCapacity: true)
            snapSourceSettings.removeAll(keepingCapacity: true)
        }
        
        /// Saves the geometry edits to the selected feature's table and resets the selection.
        func save() async throws {
            if let selectedFeature {
                selectedFeature.geometry = geometryEditor.stop()
                try await selectedFeature.table?.update(selectedFeature)
            }
            
            resetSelection()
        }
        
        /// Starts a geometry editing session with the selected feature.
        func startEditing() {
            guard let selectedFeature, let geometry = selectedFeature.geometry else {
                return
            }
            
            // Hides the selected feature on the layer.
            let featureTable = selectedFeature.table as? ArcGISFeatureTable
            let featureLayer = featureTable?.layer as? FeatureLayer
            featureLayer?.setVisible(false, for: selectedFeature)
            
            // Gets the selected feature's symbol and uses it to set the tool's style.
            let symbol = featureTable?.layerInfo?.drawingInfo?.renderer?.symbol(for: selectedFeature)
            vertexTool.style.vertexSymbol = symbol
            vertexTool.style.feedbackVertexSymbol = symbol
            vertexTool.style.selectedVertexSymbol = symbol
            vertexTool.style.vertexTextSymbol = nil
            
            geometryEditor.tool = vertexTool
            geometryEditor.start(withInitial: geometry)
        }
        
        /// Sets up the snap source settings.
        /// - Parameter assetType: The utility asset type for selected feature.
        private func setUpSnapSourcesSettings(using assetType: UtilityAssetType) async throws {
            // Analyzes the utility network to get the snap rules for the asset type.
            let rules = try await SnapRules.rules(for: utilityNetwork, assetType: assetType)
            
            // Syncs snap source settings using the snap rules.
            let snapSettings = geometryEditor.snapSettings
            try snapSettings.syncSourceSettings(rules: rules, sourceEnablingBehavior: .setFromRules)
            snapSourceSettings = filterSnapSourceSettings(snapSettings.sourceSettings)
            
            // Sets the snap source renderers to use their rule behavior symbol.
            snapSourceRenderers = snapSourceSettings.compactMap { settings in
                guard let renderedSource = settings.source as? Renderable else {
                    return nil
                }
                
                let defaultRender = renderedSource.renderer
                renderedSource.renderer = SimpleRenderer(symbol: settings.ruleBehavior.symbol)
                settings.isEnabled = true
                
                return (renderedSource, defaultRender)
            }
        }
        
        /// Recursively filters a list of snap source settings.
        /// - Parameter settings: The list of snap source settings to filter.
        /// - Returns: The snap sources settings used by this sample.
        private func filterSnapSourceSettings(
            _ settings: [SnapSourceSettings]
        ) -> [SnapSourceSettings] {
            let sourceNames: Set<String> = [.distributionPipe, .graphics, .pipelineLine, .servicePipe]
            return settings.reduce(into: [SnapSourceSettings]()) { result, setting in
                guard sourceNames.contains(setting.source.name) else {
                    return
                }
                
                if setting.source is SubtypeFeatureLayer {
                    let childSourceSettings = filterSnapSourceSettings(setting.childSourceSettings)
                    result.append(contentsOf: childSourceSettings)
                } else {
                    result.append(setting)
                }
            }
        }
    }
}

// MARK: - Extensions

/// An object that has a renderer.
private protocol Renderable: AnyObject {
    var renderer: Renderer? { get set }
}
extension GraphicsOverlay: Renderable {}
extension SubtypeSublayer: Renderable {}

private extension String {
    static let distributionPipe = "Distribution Pipe"
    static let excessFlowValve = "Excess Flow Valve"
    static let graphics = "Graphics"
    static let pipelineLine = "PipelineLine"
    /// The JSON for the example graphic's geometry.
    static var polylineJSON: String {
        "{\"paths\":[[[-9811826.6810284462,5132074.7700250093],[-9811786.4643617794,5132440.9533583419],[-9811384.2976951133,5132354.1700250087],[-9810372.5310284477,5132360.5200250093],[-9810353.4810284469,5132066.3033583425]]],\"spatialReference\":{\"wkid\":102100,\"latestWkid\":3857}}"
    }
    static let servicePipe = "Service Pipe"
}

private extension Geodatabase {
    /// Returns a temporary geodatabase with gas utility network data for Naperville.
    static func napervilleGasUtilities() -> Geodatabase {
        let temporaryGeodatabaseURL = try! FileManager.default  // swiftlint:disable:this force_try
            .url(
                for: .itemReplacementDirectory,
                in: .userDomainMask,
                appropriateFor: .temporaryDirectory,
                create: true
            )
            .appending(component: "NapervilleGasUtilities.geodatabase")
        
        try? FileManager.default.copyItem(
            at: .napervilleGasUtilitiesGeodatabase,
            to: temporaryGeodatabaseURL
        )
        
        return Geodatabase(fileURL: temporaryGeodatabaseURL)
    }
}

private extension URL {
    /// The URL to the local geodatabase file containing a data for the Naperville gas utility network.
    static var napervilleGasUtilitiesGeodatabase: URL {
        Bundle.main.url(forResource: "NapervilleGasUtilities", withExtension: "geodatabase")!
    }
}
