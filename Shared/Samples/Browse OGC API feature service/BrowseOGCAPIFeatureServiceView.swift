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
    @StateObject private var model = Model()
    
    var body: some View {
        MapViewReader { mapProxy in
            MapView(map: model.map)
                .task {
                    do {
                        model.service = try await model.makeService(url: model.defaultServiceURL)
                        let selectedInfo = model.featureCollectionInfos[0]
                        try await model.displayLayer(with: selectedInfo, proxy: mapProxy)
                    } catch {
                        print(error)
                    }
                }
        }
    }
}

private extension BrowseOGCAPIFeatureServiceView {
    @MainActor
    class Model: ObservableObject {
        /// A map with viewpoint set to Amberg, Germany.
        let map: Map = {
            let map = Map(basemapStyle: .arcGISTopographic)
            map.initialViewpoint = Viewpoint(
                center: Point(
                    latitude: 32.62,
                    longitude: 36.10
                ),
                scale: 20000
            )
            return map
        }()
        let defaultServiceURL = URL(string: "https://demo.ldproxy.net/daraa")!
        var featureCollectionInfos: [OGCFeatureCollectionInfo] = []
        var service: OGCFeatureService!
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
            if service.loadStatus == .loaded {
                featureCollectionInfos = service.serviceInfo!.featureCollectionInfos
            }
            return service
        }
        
        /// Load and display a feature layer from the OGC feature collection table.
        /// - Parameter info: The `OGCFeatureCollectionInfo` selected by user.
        func displayLayer(with info: OGCFeatureCollectionInfo, proxy: MapViewProxy) async throws {
            // Cancel if there is an existing query request.
            //                lastQuery?.cancel()
            let table = OGCFeatureCollectionTable(featureCollectionInfo: info)
            // Set the feature request mode to manual (only manual is currently
            // supported). In this mode, you must manually populate the table -
            // panning and zooming won't request features automatically.
            table.featureRequestMode = .manualCache
            let result = try await table.populateFromService(using: queryParameters, clearCache: false)
            let featureLayer = FeatureLayer(featureTable: table)
            featureLayer.renderer = getRendererForTable(withType: table.geometryType!)
            map.addOperationalLayers([featureLayer])
            await proxy.setViewpointGeometry(table.featureCollectionInfo!.extent!, padding: 50)
            self.selectedInfo = info
        }
    }
}

#Preview {
    BrowseOGCAPIFeatureServiceView()
}
