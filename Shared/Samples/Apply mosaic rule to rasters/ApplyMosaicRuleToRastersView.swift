//
//  ApplyMosaicRuleToRastersView.swift
//  Samples
//
//  Created by Christopher Webb on 6/5/24.
//  Copyright © 2024 Esri. All rights reserved.
//

import ArcGIS
import SwiftUI

struct ApplyMosaicRuleToRastersView: View {
    /// The error shown in the error alert.
    @State private var error: Error?
    /// A Boolean value indicating whether a download operation is in progress.
    @State private var isLoading = false
    
    @State private var showingAlert = false
    /// The current viewpoint of the map view.
    @State private var viewpoint: Viewpoint?
    
    @State private var map: Map = {
        let map = Map(basemapStyle: .arcGISTopographic)
        map.initialViewpoint = Viewpoint(
            center: Point(
                x: 1320141.0228999995,
                y: 6350455.22399999
            ),
            scale: 25000.0
        )
        return map
    }()
    
    @State private var imageServiceRaster = {
        let imageServiceRaster = ImageServiceRaster(
            url: .imageServiceURL
        )
        imageServiceRaster.mosaicRule = MosaicRule()
        return imageServiceRaster
    }()
    
    @State private var mosaicRulePairs: [String: MosaicRule] = {
        // A default mosaic rule object, with mosaic method as none.
        let noneRule = MosaicRule()
        noneRule.mosaicMethod = .objectID
        
        // A mosaic rule object with northwest method.
        let northWestRule = MosaicRule()
        northWestRule.mosaicMethod = .northwest
        northWestRule.mosaicOperation = .first
        
        // A mosaic rule object with center method and blend operation.
        let centerRule = MosaicRule()
        centerRule.mosaicMethod = .center
        centerRule.mosaicOperation = .blend
        
        // A mosaic rule object with byAttribute method and sort on "OBJECTID" field of the service.
        let byAttributeRule = MosaicRule()
        byAttributeRule.mosaicMethod = .attribute
        byAttributeRule.sortField = "OBJECTID"
        
        // A mosaic rule object with lockRaster method and locks 3 image rasters.
        let lockRasterRule = MosaicRule()
        lockRasterRule.mosaicMethod = .lockRaster
        lockRasterRule.addLockRasterIDs([1, 7, 12])
        
        return [
            "None": noneRule,
            "NorthWest": northWestRule,
            "Center": centerRule,
            "ByAttribute": byAttributeRule,
            "LockRaster": lockRasterRule
        ]
    }()
    
    init() {
        let rasterLayer = RasterLayer(raster: imageServiceRaster)
        map.addOperationalLayer(rasterLayer)
    }
    
    var body: some View {
        MapViewReader { mapProxy in
            MapView(map: map, viewpoint: viewpoint)
                .task {
                    guard let rasterLayer = map.operationalLayers.first as? RasterLayer else {
                        return
                    }
                    do {
                        isLoading = true
                        // Downloads raster from online service.
                        try await rasterLayer.load()
                        if let center = self.imageServiceRaster.serviceInfo?.fullExtent?.center {
                            viewpoint = Viewpoint(
                                center: center,
                                scale: 25000.0
                            )
                        }
                        isLoading = false
                    } catch {
                        // Presents an error message if the raster fails to load.
                        self.error = error
                    }
                }
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button("Rules") {
                            showingAlert = true
                        }
                        .actionSheet(isPresented: $showingAlert) {
                            ActionSheet(
                                title: Text("Mosiac Rules"),
                                message: Text("Select a mosiac rule to apply to the raster:"),
                                buttons: createButtons(mapProxy: mapProxy)
                            )
                        }
                    }
                }
                .overlay(alignment: .center) {
                    if isLoading {
                        ProgressView("Loading...")
                            .padding()
                            .background(.ultraThickMaterial)
                            .cornerRadius(10)
                            .shadow(radius: 50)
                    }
                }
        }
        .errorAlert(presentingError: $error)
    }
    
    private func createButtons(mapProxy: MapViewProxy) -> [Alert.Button] {
        var results = [Alert.Button]()
        for key in mosaicRulePairs.keys {
            results.append(
                Alert.Button.default(Text(key)) {
                    Task {
                        await self.mosiacRuleSelect(
                            at: key,
                            using: mapProxy
                        )
                    }
                }
            )
        }
        return results
    }
    
    private func mosiacRuleSelect(at selection: String, using proxy: MapViewProxy) async {
        imageServiceRaster.mosaicRule = mosaicRulePairs[selection]
        if let center = self.imageServiceRaster.serviceInfo?.fullExtent?.center {
            await proxy.setViewpoint(
                Viewpoint(
                    center: center,
                    scale: 25000.0
                )
            )
        }
    }
}

private extension URL {
    static let imageServiceURL = URL(string: "https://sampleserver7.arcgisonline.com/server/rest/services/amberg_germany/ImageServer")!
}

#Preview {
    ApplyMosaicRuleToRastersView()
}
