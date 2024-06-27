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
import ArcGISToolkit
import SwiftUI

struct BrowseOGCAPIFeatureServiceView: View {
    /// The tracking status for the loading operation.
    @State private var isLoading = false
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    /// Ensures that the alert is only shown once.
    @State private var presentAlert = true
    
    /// The data model for the sample.
    @StateObject private var model = Model()
    
    /// The user input for the OGC service resource.
    @State private var userInput = "https://demo.ldproxy.net/daraa"
    
    /// The selected layer name.
    @State private var selection: String = ""
    
    var body: some View {
        MapViewReader { mapProxy in
            MapView(map: model.map)
                .onDrawStatusChanged { drawStatus in
                    // Updates the state when the map's draw status changes.
                    withAnimation {
                        if drawStatus == .completed {
                            isLoading = false
                        }
                    }
                }
                .overlay(alignment: .center) {
                    if isLoading {
                        ProgressView("Loading…")
                            .padding()
                            .background(.ultraThickMaterial)
                            .cornerRadius(10)
                            .shadow(radius: 50)
                    }
                }
                .toolbar {
                    ToolbarItemGroup(placement: .bottomBar) {
                        // Button in toolbar that allows user to launch the load alert.
                        Button(action: {
                            presentAlert = true
                        }, label: {
                            Text("Open Service")
                        })
                        Spacer()
                        // Layers button will not appear until selection is set.
                        if !selection.isEmpty {
                            Picker("Layers", selection: $selection) {
                                ForEach(model.layerNames, id: \.self) { title in
                                    Text(title)
                                }
                            }.task(id: selection) {
                                model.update(for: selection)
                                if let selection = model.selectedInfo {
                                    do {
                                        try await model.displayLayer(with: selection)
                                        if let extent = model.completeExtent {
                                            await mapProxy.setViewpointGeometry(
                                                extent,
                                                padding: 100
                                            )
                                        }
                                    } catch {
                                        self.error = error
                                    }
                                }
                            }
                            .pickerStyle(.automatic)
                        }
                    }
                }
                .alert("Load OGC API feature service", isPresented: $presentAlert, actions: {
                    // Alert is set with a default url that the user can edit.
                    TextField("URL:", text: $userInput)
                    Button("Load", action: {
                        presentAlert = false
                        isLoading = true
                        Task {
                            do {
                                try await model.loadOGCFeatureData(url: URL(string: userInput))
                                // This selects the first layer in the layer name list. This is
                                // needed so that the layer selection picker set in the toolbar.
                                selection = model.layerNames.first ?? ""
                                if let extent = model.completeExtent {
                                    await mapProxy.setViewpointGeometry(
                                        extent,
                                        padding: 100
                                    )
                                }
                            } catch {
                                self.error = error
                            }
                        }
                    })
                    Button("Cancel", role: .cancel, action: {
                        presentAlert = false
                    })
                }, message: {
                    Text("Please provide a URL to an OGC API feature service.")
                })
                .errorAlert(presentingError: $error)
        }
    }
}

private extension BrowseOGCAPIFeatureServiceView {
    @MainActor
    class Model: ObservableObject {
        let map: Map = {
            let map = Map(basemapStyle: .arcGISTopographic)
            map.initialViewpoint = Viewpoint(
                center: Point(
                    latitude: 32.62,
                    longitude: 36.10
                ),
                scale: 200000
            )
            return map
        }()
        
        @Published var layerNames: [String] = []
        /// The geometry that represents a rectangular shape that encompasses the area.
        private(set) var completeExtent: Envelope?
        private var featureCollectionInfos: [OGCFeatureCollectionInfo] = []
        private var service: OGCFeatureService!
        private(set) var selectedInfo: OGCFeatureCollectionInfo?
        
        /// The query parameters to populate features from the OGC API service.
        private let queryParameters: QueryParameters = {
            let queryParameters = QueryParameters()
            // Set a limit of 1000 on the number of returned features per request,
            // because the default on some services could be as low as 10.
            queryParameters.maxFeatures = 1_000
            return queryParameters
        }()
        
        /// Returns a renderer for a specified geometry type.
        /// - Parameter geometryType: The ARCGis Geometry type.
        /// - Returns: Returns a `SimpleRenderer` optional with the correct settings for the given geometry.
        private func getRenderer(withType geometryType: Geometry.Type) -> SimpleRenderer? {
            var renderer: SimpleRenderer?
            if geometryType == Point.self {
                renderer = SimpleRenderer(
                    symbol: SimpleMarkerSymbol(
                        style: .circle,
                        color: .blue,
                        size: 5
                    )
                )
            }
            if geometryType == Multipoint.self {
                renderer = SimpleRenderer(
                    symbol: SimpleMarkerSymbol(
                        style: .circle,
                        color: .blue,
                        size: 5
                    )
                )
            }
            if geometryType == Polyline.self {
                renderer = SimpleRenderer(
                    symbol: SimpleLineSymbol(
                        style: .solid,
                        color: .blue,
                        width: 1
                    )
                )
            }
            if geometryType == Polygon.self {
                renderer = SimpleRenderer(
                    symbol: SimpleFillSymbol(
                        style: .solid,
                        color: .blue,
                        outline: nil
                    )
                )
            }
            return renderer
        }
        
        /// Create and load the OGC API features service from a URL.
        /// - Parameter url: The URL of the OGC service.
        /// - Returns: Returns a `OCGFeatureService` that has been loaded and initialized.
        private func makeService(url: URL) async throws -> OGCFeatureService {
            let service = OGCFeatureService(url: url)
            try await service.load()
            if service.loadStatus == .loaded,
               let serviceInfo = service.serviceInfo {
                featureCollectionInfos = serviceInfo.featureCollectionInfos
                layerNames = featureCollectionInfos.map(\.title)
            }
            return service
        }
        
        /// Loads OGC service for a URL so that it can be rendered on the map.
        /// - Parameters:
        ///   - mapProxy: Allows access to `MapView`
        ///   - url: The URL of the OGC service.
        func loadOGCFeatureData(url: URL?) async throws {
            service = try await makeService(url: url ?? .defaultServiceURL)
            try await displayLayer(with: featureCollectionInfos[0])
        }
        
        /// Updates the selected info property for the users selection.
        /// - Parameter selection: String with the name of the selected layer to display.
        func update(for selection: String) {
            selectedInfo = featureCollectionInfos.first(where: { $0.title == selection })
        }
        
        /// Load and display a feature layer from the OGC feature collection table.
        /// - Parameter info: The `OGCFeatureCollectionInfo` selected by user.
        func displayLayer(with info: OGCFeatureCollectionInfo) async throws {
            let table = OGCFeatureCollectionTable(featureCollectionInfo: info)
            // Set the feature request mode to manual (only manual is currently
            // supported). In this mode, you must manually populate the table -
            // panning and zooming won't request features automatically.
            table.featureRequestMode = .manualCache
            _ = try await table.populateFromService(
                using: queryParameters,
                clearCache: false
            )
            completeExtent = info.extent
            let featureLayer = FeatureLayer(featureTable: table)
            if let geoType = table.geometryType {
                featureLayer.renderer = getRenderer(withType: geoType)
                map.addOperationalLayers([featureLayer])
                selectedInfo = info
            }
        }
    }
}

private extension URL {
    // This is for fallback url.
    static let defaultServiceURL = URL(string: "https://demo.ldproxy.net/daraa")!
}

#Preview {
    BrowseOGCAPIFeatureServiceView()
}
