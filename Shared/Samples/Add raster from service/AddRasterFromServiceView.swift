//
//  AddRasterFromServiceView.swift
//  Samples
//
//  Created by Christopher Webb on 6/3/24.
//  Copyright © 2024 Esri. All rights reserved.
//

import SwiftUI
import ArcGIS

struct AddRasterFromServiceView: View {
    /// The error shown in the error alert.
    @State private var error: Error?
    
    /// The current viewpoint of the map view.
    @State private var viewpoint: Viewpoint?
    
    /// A Boolean value indicating whether a download operation is in progress.
    @State private var isDownloading = false
    
    /// A map with a topographic basemap.
    @State private var map: Map = {
        let map = Map(basemapStyle: .arcGISDarkGrayBase)
        let imageServiceRaster = ImageServiceRaster(url: .imageServiceURL)
        let rasterLayer = RasterLayer(raster: imageServiceRaster)
        map.addOperationalLayer(rasterLayer)
        return map
    }()
    
    var body: some View {
        MapViewReader { mapViewProxy in
            MapView(map: map, viewpoint: viewpoint)
                .onViewpointChanged(kind: .centerAndScale) { viewpoint = $0 }
                .overlay(alignment: .center) {
                    if isDownloading {
                        ProgressView("Downloading...")
                            .padding()
                            .background(.ultraThickMaterial)
                            .cornerRadius(10)
                            .shadow(radius: 50)
                    }
                }
                .task {
                    do {
                        isDownloading = true
                        defer { isDownloading = false }
                        let rasterLayer = map.operationalLayers.first! as! RasterLayer
                        try await rasterLayer.load()
                        var point = Point(x: -13637000, y: 4550000, spatialReference:.webMercator)
                        await mapViewProxy.setViewpointCenter(point, scale: 100000)
                    } catch {
                        // Presents an error message if the raster fails to load.
                        self.error = error
                    }
                }
        }
    }
}

extension URL {
    static let imageServiceURL = URL(string: "https://gis.ngdc.noaa.gov/arcgis/rest/services/bag_bathymetry/ImageServer")!
}

#Preview {
    AddRasterFromServiceView()
}
