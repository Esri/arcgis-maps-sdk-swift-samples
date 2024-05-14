// Copyright 2022 Esri
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

struct GenerateOfflineMapWithCustomParametersView: View {
    /// A Boolean value indicating whether the job is generating an offline map.
    @State private var isGeneratingOfflineMap = false
    
    /// A Boolean value indicating whether the job is cancelling.
    @State private var isCancellingJob = false
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    /// The view model for this sample.
    @StateObject private var model = Model()
    
    /// A Boolean value indicating whether to set the custom parameters.
    @State private var isShowingSetCustomParameters = false
    
    var body: some View {
        GeometryReader { geometry in
            MapViewReader { mapView in
                MapView(map: model.offlineMap ?? model.onlineMap)
                    .interactionModes(isGeneratingOfflineMap ? [] : [.pan, .zoom])
                    .errorAlert(presentingError: $error)
                    .task {
                        do {
                            try await model.initializeOfflineMapTask()
                        } catch {
                            self.error = error
                        }
                    }
                    .onDisappear {
                        Task { await model.cancelJob() }
                    }
                    .overlay {
                        Rectangle()
                            .stroke(.red, lineWidth: 2)
                            .padding(EdgeInsets(top: 20, leading: 20, bottom: 44, trailing: 20))
                            .opacity(model.offlineMap == nil ? 1 : 0)
                    }
                    .overlay {
                        if isGeneratingOfflineMap,
                           let progress = model.generateOfflineMapJob?.progress {
                            VStack(spacing: 16) {
                                ProgressView(progress)
                                    .progressViewStyle(.linear)
                                    .frame(maxWidth: 200)
                                
                                Button("Cancel") {
                                    isCancellingJob = true
                                }
                                .disabled(isCancellingJob)
                                .task(id: isCancellingJob) {
                                    guard isCancellingJob else { return }
                                    // Cancels the job.
                                    await model.cancelJob()
                                    // Sets cancelling the job and generating an
                                    // offline map to false.
                                    isCancellingJob = false
                                    isGeneratingOfflineMap = false
                                }
                            }
                            .padding()
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                            .shadow(radius: 3)
                        }
                    }
                    .overlay(alignment: .top) {
                        Text("Offline map generated.")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(8)
                            .background(.thinMaterial, ignoresSafeAreaEdges: .horizontal)
                            .opacity(model.offlineMap != nil ? 1 : 0)
                    }
                    .toolbar {
                        ToolbarItem(placement: .bottomBar) {
                            Button("Generate Offline Map") {
                                isShowingSetCustomParameters.toggle()
                            }
                            .disabled(model.isGenerateDisabled || isGeneratingOfflineMap)
                            .popover(isPresented: $isShowingSetCustomParameters) {
                                // Creates a rectangle from the area of interest.
                                let viewRect = geometry.frame(in: .local).inset(
                                    by: UIEdgeInsets(
                                        top: 20,
                                        left: geometry.safeAreaInsets.leading + 20,
                                        bottom: 44,
                                        right: -geometry.safeAreaInsets.trailing + 20
                                    )
                                )
                                // Creates an envelope from the rectangle.
                                if let extent = mapView.envelope(fromViewRect: viewRect) {
                                    CustomParameters(
                                        model: model,
                                        extent: extent,
                                        isGeneratingOfflineMap: $isGeneratingOfflineMap
                                    )
                                        .presentationDetents([.fraction(1.0)])
                                        .frame(idealWidth: 320, idealHeight: 720)
                                }
                            }
                            .task(id: isGeneratingOfflineMap) {
                                guard isGeneratingOfflineMap else { return }
                                
                                do {
                                    // Generates an offline map.
                                    try await model.generateOfflineMap()
                                } catch {
                                    self.error = error
                                }
                                
                                // Sets generating an offline map to false.
                                isGeneratingOfflineMap = false
                            }
                        }
                    }
            }
        }
    }
}

extension GenerateOfflineMapWithCustomParametersView {
    /// The model used to store the geo model and other expensive objects
    /// used in this view.
    @MainActor
    class Model: ObservableObject {
        /// The offline map that is generated.
        @Published private(set) var offlineMap: Map!
        
        /// A Boolean value indicating whether the generate button is disabled.
        @Published private(set) var isGenerateDisabled = true
        
        /// The generate offline map job.
        @Published private(set) var generateOfflineMapJob: GenerateOfflineMapJob!
        
        /// The offline map task.
        private var offlineMapTask: OfflineMapTask!
        
        /// A URL to a temporary directory where the offline map files are stored.
        private let temporaryDirectory = createTemporaryDirectory()
        
        // The parameters used to take the map offline.
        var offlineMapParameters: GenerateOfflineMapParameters?
        
        // The parameter overrides used to take the map offline.
        var offlineMapParameterOverrides: GenerateOfflineMapParameterOverrides?
        
        /// The online map that is loaded from a portal item.
        let onlineMap: Map = {
            // A portal item displaying the Naperville, IL water network.
            let napervillePortalItem = PortalItem(
                portal: .arcGISOnline(connection: .anonymous),
                id: .napervilleWaterNetwork
            )
            
            // Creates map with portal item.
            let map = Map(item: napervillePortalItem)
            
            // Sets the min scale to avoid requesting a huge download.
            map.minScale = 1e4
            
            return map
        }()
        
        deinit {
            // Removes the temporary directory.
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        
        /// Initializes the offline map task.
        func initializeOfflineMapTask() async throws {
            // Waits for the online map to load.
            try await onlineMap.load()
            offlineMapTask = OfflineMapTask(onlineMap: onlineMap)
            isGenerateDisabled = false
        }
        
        /// Creates the generate offline map parameters.
        /// - Parameter areaOfInterest: The area of interest to create the parameters for.
        /// - Returns: A `GenerateOfflineMapParameters` if there are no errors.
        private func makeGenerateOfflineMapParameters(
            areaOfInterest: Envelope
        ) async throws -> GenerateOfflineMapParameters {
            // Returns the default parameters for the offline map task.
            return try await offlineMapTask.makeDefaultGenerateOfflineMapParameters(
                areaOfInterest: areaOfInterest
            )
        }
        
        /// Creates the generate offline map parameter overrides.
        /// - Parameter parameters: The generate offline map parameters.
        /// - Returns: A `GenerateOfflineMapParameterOverrides` id there are no errors.
        private func makeGenerateParameterOverrides(
            parameters: GenerateOfflineMapParameters
        ) async throws -> GenerateOfflineMapParameterOverrides {
            // Returns the overrides.
            return try await offlineMapTask.makeGenerateOfflineMapParameterOverrides(
                parameters: parameters
            )
        }
        
        /// Sets up the model by getting the generate offline map parameters and parameter
        /// overrides.
        /// - Parameter areaOfInterest: The area of interest to create the parametes and parameter
        /// overrides for.
        func setUpParametersAndOverrides(extent: Envelope) async throws {
            offlineMapParameters = try await makeGenerateOfflineMapParameters(areaOfInterest: extent)
            if let offlineMapParameters {
                offlineMapParameterOverrides = try await makeGenerateParameterOverrides(
                    parameters: offlineMapParameters
                )
            }
        }
        
        /// Generates the offline map.
        func generateOfflineMap() async throws {
            // Disables the generate offline map button.
            isGenerateDisabled = true
            
            guard let parameters = offlineMapParameters,
                  let overrides = offlineMapParameterOverrides,
                  let extent = parameters.areaOfInterest?.extent else { return }
            
            // Creates the generate offline map job based on the parameters and overrides.
            generateOfflineMapJob = offlineMapTask.makeGenerateOfflineMapJob(
                parameters: parameters,
                downloadDirectory: temporaryDirectory,
                overrides: overrides
            )
            
            // Starts the job.
            generateOfflineMapJob.start()
            
            defer {
                generateOfflineMapJob = nil
                isGenerateDisabled = offlineMap != nil
            }
            
            // Awaits the output of the job.
            let output = try await generateOfflineMapJob.output
            // Sets the offline map to the output's offline map.
            offlineMap = output.offlineMap
            // Sets the initial viewpoint of the offline map.
            offlineMap.initialViewpoint = Viewpoint(boundingGeometry: extent.expanded(by: 0.8))
        }
        
        /// Cancels the generate offline map job.
        func cancelJob() async {
            // Cancels the generate offline map job.
            await generateOfflineMapJob?.cancel()
            generateOfflineMapJob = nil
        }
        
        /// Creates a temporary directory.
        private static func createTemporaryDirectory() -> URL {
            // swiftlint:disable:next force_try
            try! FileManager.default.url(
                for: .itemReplacementDirectory,
                in: .userDomainMask,
                appropriateFor: FileManager.default.temporaryDirectory,
                create: true
            )
        }
        
        // MARK: - Basemap helpers
        private func getExportTileCacheParametersForBasemapLayer() -> ExportTileCacheParameters? {
            if let basemapLayer = onlineMap.basemap?.baseLayers.first as? Layer {
                if let key = OfflineMapParametersKey(layer: basemapLayer) {
                    return offlineMapParameterOverrides?.exportTileCacheParameters[key]
                }
            }
            return nil
        }
        
        /// Sets the scale level range so that only the levels between the min and max inclusive,
        /// are downloaded. Note that lower values are zoomed further out,
        /// i.e. 0 has the least detail, but one tile covers the entire Earth.
        /// Parameters:
        /// - minScaleLevel: The minumum scale level to download foe the basemap.
        /// - maxScaleLevel: The maximun scale level to download for the basemap.
        func restrictBasemapScaleLevelRangeTo(minScaleLevel: Double, maxScaleLevel: Double) {
            guard let tileCacheParameters = getExportTileCacheParametersForBasemapLayer(),
                  // Ensure that the lower bound of the range is not greater than the upper bound
                  minScaleLevel <= maxScaleLevel else {
                return
            }
            
            let scaleLevelIDs = Array(Int(minScaleLevel.rounded())...Int(maxScaleLevel.rounded()))
            // Override the default level IDs
            tileCacheParameters.removeAllLevelIDs()
            tileCacheParameters.addLevelIDs(scaleLevelIDs)
        }
        
        /// Adds extra padding to the extent envelope to fetch a larger area, in meters.
        /// - Parameter basemapExtentBufferDistance: The distance to extend the area of interest.
        func bufferBasemapAreaOfInterest(by basemapExtentBufferDistance: Double) {
            guard let tileCacheParameters = getExportTileCacheParametersForBasemapLayer(),
                  // The area initially specified for download when the default parameters object
                  // was created
                  let areaOfInterest = tileCacheParameters.areaOfInterest else {
                return
            }
            
            // Assuming the distance is positive, expand the downloaded area by the given amount
            let bufferedArea = GeometryEngine.buffer(
                around: areaOfInterest,
                distance: basemapExtentBufferDistance
            )
            // Override the default area of interest
            tileCacheParameters.areaOfInterest = bufferedArea
        }

        // MARK: - Layer helpers
        /// Retrieves the operational layer in the map with the given name, if it exists.
        private func operationalMapLayer(named name: String) -> Layer? {
            return onlineMap.operationalLayers.first { $0.name == name }
        }
        
        /// The service ID retrived from the layer's `ArcGISFeatureLayerInfo`, if it is a feature layer.
        /// Needed for use in conjunction with the `layerID` of `GenerateLayerOption`.
        /// This is not the same as the `layerID` property of `Layer`.
        private func serviceLayerID(for layer: Layer) -> Int? {
            if let featureLayer = layer as? FeatureLayer,
               let featureTable = featureLayer.featureTable as? ArcGISFeatureTable,
               let featureLayerInfo = featureTable.layerInfo {
                return featureLayerInfo.serviceLayerID
            }
            return nil
        }
        
        /// Filters the hydrants that will be shown in the map by flow rate. Only hydrants the have
        /// a higher flow rate than the minimum flow rate will be shown.
        /// - Parameter minHydrantFlowRate: The minimum flow rate for hydrants shown on the map.
        func filterHydrantFlowRate(to minHydrantFlowRate: Double) {
            for option in getGenerateGeodatabaseParametersLayerOptions(forLayerNamed: "Hydrant") {
                // Set the SQL where clause for this layer's options, filtering features based on 
                // the FLOW field values
                option.whereClause = "FLOW >= \(minHydrantFlowRate)"
            }
        }
        
        /// Excludes the layer with the specified name from the offline map.
        /// - Parameter name: The name of the layer to be excluded.
        func excludeLayer(named name: String) {
            if let layer = operationalMapLayer(named: name),
               let serviceLayerID = serviceLayerID(for: layer),
               let parameters = getGenerateGeodatabaseParameters(forLayer: layer),
               let layerOption = parameters.layerOptions.first(where: { $0.layerID == serviceLayerID }) {
                // Remove the options for this layer from the parameters
                parameters.removeLayerOption(layerOption)
            }
        }
        
        /// Sets the layer options to crop the water pipes according the specified Boolean value.
        /// - Parameter cropWaterPipesToExtent: A Boolean value indicating if the water pipes shoule
        /// be cropped to the area of interest.
        func evaluatePipeLayersExtentCropping(for cropWaterPipesToExtent: Bool) {
            // If the switch is off
            if !cropWaterPipesToExtent {
                // Two layers contain pipes, so loop through both
                for pipeLayerName in ["Main", "Lateral"] {
                    for option in getGenerateGeodatabaseParametersLayerOptions(
                        forLayerNamed: pipeLayerName
                    ) {
                        // Turn off the geometry extent evaluation so that the entire layer is downloaded
                        option.usesGeometry = false
                    }
                }
            }
        }

        // MARK: - AGSGenerateGeodatabaseParameters helpers
        /// Retrieves this layer's parameters from the `generateGeodatabaseParameters` dictionary.
        private func getGenerateGeodatabaseParameters(
            forLayer layer: Layer
        ) -> GenerateGeodatabaseParameters? {
            /// The parameters key for this layer
            if let key = OfflineMapParametersKey(layer: layer) {
                return offlineMapParameterOverrides?.generateGeodatabaseParameters[key]
            }
            return nil
        }
        /// Retrieves the layer's options from the layer's parameter in the 
        /// `generateGeodatabaseParameters` dictionary.
        private func getGenerateGeodatabaseParametersLayerOptions(
            forLayerNamed name: String
        ) -> [GenerateLayerOption] {
            if let layer = operationalMapLayer(named: name),
               let serviceLayerID = serviceLayerID(for: layer),
               let parameters = getGenerateGeodatabaseParameters(forLayer: layer) {
                // The layers options may correspond to multiple layers, so filter based on the ID 
                // of the target layer.
                return parameters.layerOptions.filter { $0.layerID == serviceLayerID }
            }
            return []
        }
    }
}

private extension Envelope {
    /// Expands the envelope by a given factor.
    /// - Parameter factor: The amount to expand the envelope by.
    /// - Returns: An envelope expanded by the specified factor.
    func expanded(by factor: Double) -> Envelope {
        let builder = EnvelopeBuilder(envelope: self)
        builder.expand(by: factor)
        return builder.toGeometry()
    }
}

private extension PortalItem.ID {
     /// The portal item ID of the Naperville water network web map to be displayed on the map.
     static var napervilleWaterNetwork: Self { Self("acc027394bc84c2fb04d1ed317aac674")! }
 }

#Preview {
    GenerateOfflineMapWithCustomParametersView()
}
