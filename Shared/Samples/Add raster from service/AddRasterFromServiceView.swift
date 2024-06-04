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
                .task {
                    do {
                        let rasterLayer = map.operationalLayers.first! as! RasterLayer
                        try await rasterLayer.load()
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
