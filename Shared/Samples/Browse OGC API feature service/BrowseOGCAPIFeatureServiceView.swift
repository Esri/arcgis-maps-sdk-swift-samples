//
//  BrowseOGCAPIFeatureServiceView.swift
//  Samples
//
//  Created by Christopher Webb on 6/21/24.
//  Copyright © 2024 Esri. All rights reserved.
//

import ArcGIS
import ArcGISToolkit
import SwiftUI

struct BrowseOGCAPIFeatureServiceView: View {
    @State private var error: Error?
    @State private var presentAlert = true
    @StateObject private var model = Model()
    @State private var userInput = "https://demo.ldproxy.net/daraa"
    @State private var selection = ""
    @State private var shown: Bool = false
    
    var body: some View {
        MapViewReader { mapProxy in
            MapView(map: model.map)
                .toolbar {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Picker("Layers", selection: $selection) {
                            ForEach(model.elements, id: \.self) { title in
                                Text(title)
                            }
                        }.task(id: selection) {
                            let element = model.featureCollectionInfos.first(where: { $0.title == selection })
                            model.selectedInfo = element
                            if let selection = model.selectedInfo {
                                do {
                                    try await model.displayLayer(with: selection, proxy: mapProxy)
                                } catch {
                                    self.error = error
                                }
                            }
                        }
                        .pickerStyle(.automatic)
                    }
                }
                .alert("Set URL", isPresented: $presentAlert, actions: {
                    TextField("URL:", text: $userInput)
                    Button("Go", action: {
                        presentAlert = false
                        Task {
                            do {
                                try await model.loadOGCFeatureData(mapProxy: mapProxy, url: URL(string: userInput))
                            } catch {
                                self.error = error
                            }
                        }
                    })
                }, message: {
                    Text("Please enter the address of the OGC API")
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
        
        @Published var elements: [String] = []
        
        var featureCollectionInfos: [OGCFeatureCollectionInfo] = []
        private var service: OGCFeatureService!
        var selectedInfo: OGCFeatureCollectionInfo?
        
        /// The query parameters to populate features from the OGC API service.
        let queryParameters: QueryParameters = {
            let queryParameters = QueryParameters()
            // Set a limit of 1000 on the number of returned features per request,
            // because the default on some services could be as low as 10.
            queryParameters.maxFeatures = 1_000
            return queryParameters
        }()
        
        func getRendererForTable(withType geometryType: Geometry.Type) -> SimpleRenderer? {
            var renderer: SimpleRenderer?
            if geometryType == Point.self {
                renderer = SimpleRenderer(symbol: SimpleMarkerSymbol(style: .circle, color: .blue, size: 5))
            }
            if geometryType == Multipoint.self {
                renderer = SimpleRenderer(symbol: SimpleMarkerSymbol(style: .circle, color: .blue, size: 5))
            }
            if geometryType == Polyline.self {
                renderer = SimpleRenderer(symbol: SimpleLineSymbol(style: .solid, color: .blue, width: 1))
            }
            if geometryType == Polygon.self {
                renderer = SimpleRenderer(symbol: SimpleFillSymbol(style: .solid, color: .blue, outline: nil))
            }
            return renderer
        }
        
        /// Create and load the OGC API features service from a URL.
        func makeService(url: URL) async throws -> OGCFeatureService {
            let service = OGCFeatureService(url: url)
            try await service.load()
            if service.loadStatus == .loaded,
               let serviceInfo = service.serviceInfo {
                featureCollectionInfos = serviceInfo.featureCollectionInfos
                self.elements = featureCollectionInfos.map(\.title)
            }
            return service
        }
        
        func loadOGCFeatureData(mapProxy: MapViewProxy, url: URL?) async throws {
            service = try await makeService(url: url ?? .defaultServiceURL)
            try await displayLayer(with: featureCollectionInfos[0], proxy: mapProxy)
        }
        
        /// Load and display a feature layer from the OGC feature collection table.
        /// - Parameter info: The `OGCFeatureCollectionInfo` selected by user.
        func displayLayer(with info: OGCFeatureCollectionInfo, proxy: MapViewProxy) async throws {
            let table = OGCFeatureCollectionTable(featureCollectionInfo: info)
            // Set the feature request mode to manual (only manual is currently
            // supported). In this mode, you must manually populate the table -
            // panning and zooming won't request features automatically.
            table.featureRequestMode = .manualCache
            _ = try await table.populateFromService(using: queryParameters, clearCache: false)
            if let extent = info.extent {
                let featureLayer = FeatureLayer(featureTable: table)
                if let geoType = table.geometryType {
                    featureLayer.renderer = getRendererForTable(withType: geoType)
                    map.addOperationalLayers([featureLayer])
                    await proxy.setViewpointGeometry(extent, padding: 100)
                    self.selectedInfo = info
                }
            }
        }
    }
}

private extension URL {
    static let defaultServiceURL = URL(string: "https://demo.ldproxy.net/daraa")!
}

#Preview {
    BrowseOGCAPIFeatureServiceView()
}
