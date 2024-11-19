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

struct BrowseOGCAPIFeatureServiceView: View {
    /// The error shown in the error alert.
    @State private var error: Error?
    
    /// A Boolean value indicating whether the text field alert should be presented.
    @State private var textFieldAlertIsPresented = false
    
    /// The data model for the sample.
    @StateObject private var model = Model()
    
    /// The user input for the OGC service resource.
    @State private var userInput = URL.daraaService.absoluteString
    
    /// The selected feature collection's title.
    @State private var selectedTitle = ""
    
    var body: some View {
        MapViewReader { mapProxy in
            MapView(map: model.map)
                .toolbar {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button("Open Service") {
                            textFieldAlertIsPresented = true
                        }
                        
                        Spacer()
                        
                        if !model.featureCollectionTitles.isEmpty {
                            Picker("Layers", selection: $selectedTitle) {
                                ForEach(model.featureCollectionTitles, id: \.self) { title in
                                    Text(title)
                                }
                            }
                            .task(id: selectedTitle) {
                                guard !selectedTitle.isEmpty else { return }
                                let featureCollectionInfo = model.featureCollectionInfos[selectedTitle]!
                                do {
                                    try await model.displayLayer(with: featureCollectionInfo)
                                    if let extent = featureCollectionInfo.extent {
                                        await mapProxy.setViewpointGeometry(extent, padding: 100)
                                    }
                                } catch {
                                    self.error = error
                                }
                            }
                        }
                    }
                }
                .alert("Load OGC API feature service", isPresented: $textFieldAlertIsPresented) {
                    // Text field has a default OGC API URL.
                    TextField("URL", text: $userInput)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                    Button("Load") {
                        guard let url = URL(string: userInput) else { return }
                        Task {
                            do {
                                try await model.loadOGCFeatureData(url: url)
                                // Set the picker selection to the first title in the title list.
                                if let title = model.featureCollectionTitles.first,
                                   let extent = model.featureCollectionInfos[title]?.extent {
                                    selectedTitle = title
                                    await mapProxy.setViewpointGeometry(extent, padding: 100)
                                }
                            } catch {
                                self.error = error
                            }
                        }
                    }
                    .disabled(userInput.isEmpty)
                    Button("Cancel", role: .cancel) {
                        // Reset the default value of the text field.
                        userInput = URL.daraaService.absoluteString
                    }
                } message: {
                    Text("Please provide a URL to an OGC API feature service.")
                }
                .onAppear {
                    textFieldAlertIsPresented = true
                }
                .errorAlert(presentingError: $error)
        }
    }
}

private extension BrowseOGCAPIFeatureServiceView {
    @MainActor
    class Model: ObservableObject {
        /// A map with a topographic basemap of the Daraa, Syria.
        let map: Map = {
            let map = Map(basemapStyle: .arcGISTopographic)
            map.initialViewpoint = Viewpoint(
                center: Point(latitude: 32.62, longitude: 36.10),
                scale: 200_000
            )
            return map
        }()
        
        /// The titles of the feature collection infos in the OGC API.
        @Published private(set) var featureCollectionTitles: [String] = []
        
        /// The OGC feature collection info from the OCG API.
        private(set) var featureCollectionInfos: [String: OGCFeatureCollectionInfo] = [:]
        
        /// The OGC API feature service.
        private var service: OGCFeatureService!
        
        /// The query parameters to populate features from the OGC API service.
        private let queryParameters: QueryParameters = {
            let queryParameters = QueryParameters()
            // Set a limit of 1000 on the number of returned features per request,
            // because the default on some services could be as low as 10.
            queryParameters.maxFeatures = 1_000
            return queryParameters
        }()
        
        /// Returns a renderer with the appropriate symbol type for a geometry type.
        /// - Parameter geometryType: The geometry type.
        /// - Returns: A `SimpleRenderer` with the correct symbol for the given geometry.
        private func makeRenderer(withType geometryType: Geometry.Type) -> SimpleRenderer? {
            let symbol: Symbol
            switch geometryType {
            case is Point.Type, is Multipoint.Type:
                symbol = SimpleMarkerSymbol(style: .circle, color: .blue, size: 5)
            case is Polyline.Type:
                symbol = SimpleLineSymbol(style: .solid, color: .blue, width: 1)
            case is ArcGIS.Polygon.Type, is Envelope.Type:
                symbol = SimpleFillSymbol(style: .solid, color: .blue)
            default:
                return nil
            }
            return SimpleRenderer(symbol: symbol)
        }
        
        /// Creates and loads the OGC API features service from a URL.
        /// - Parameter url: The URL of the OGC service.
        /// - Returns: Returns a loaded `OCGFeatureService`.
        private func makeService(url: URL) async throws -> OGCFeatureService {
            let service = OGCFeatureService(url: url)
            try await service.load()
            if let serviceInfo = service.serviceInfo {
                let infos = serviceInfo.featureCollectionInfos
                featureCollectionTitles = infos.map(\.title)
                // The sample assumes there is no duplicate titles in the service.
                // Collections with duplicate titles will be discarded.
                featureCollectionInfos = Dictionary(
                    infos.map { ($0.title, $0) },
                    uniquingKeysWith: { (title, _) in title }
                )
            }
            return service
        }
        
        /// Loads OGC service for a URL so that it can be rendered on the map.
        /// - Parameter url: The URL of the OGC service.
        func loadOGCFeatureData(url: URL) async throws {
            service = try await makeService(url: url)
            if let firstFeatureCollectionTitle = featureCollectionTitles.first,
               let info = featureCollectionInfos[firstFeatureCollectionTitle] {
                try await displayLayer(with: info)
            }
        }
        
        /// Populates and displays a feature layer from an OGC feature collection table.
        /// - Parameter info: The `OGCFeatureCollectionInfo` selected by user.
        func displayLayer(with info: OGCFeatureCollectionInfo) async throws {
            map.removeAllOperationalLayers()
            let table = OGCFeatureCollectionTable(featureCollectionInfo: info)
            // Set the feature request mode to manual (only manual is currently
            // supported). In this mode, you must manually populate the table -
            // panning and zooming won't request features automatically.
            table.featureRequestMode = .manualCache
            _ = try await table.populateFromService(
                using: queryParameters,
                clearCache: false
            )
            let featureLayer = FeatureLayer(featureTable: table)
            if let geometryType = table.geometryType {
                featureLayer.renderer = makeRenderer(withType: geometryType)
                map.addOperationalLayer(featureLayer)
            }
        }
    }
}

private extension URL {
    /// The Daraa, Syria OGC API feature service URL.
    static var daraaService: URL { URL(string: "https://demo.ldproxy.net/daraa")! }
}

#Preview {
    BrowseOGCAPIFeatureServiceView()
}
