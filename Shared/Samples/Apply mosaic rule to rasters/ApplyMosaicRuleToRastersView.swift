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

/// tw
struct ApplyMosaicRuleToRastersView: View {
    /// A Boolean value indicating whether a operation is in progress.
    @State private var isLoading = false
    
    /// A Boolean value indicating whether the action sheet is showing.
    @State private var showingAlert = false
    
    /// The current viewpoint of the map view.
    @State private var viewpoint: Viewpoint?
    
    /// The data model for the sample.
    @StateObject private var model = Model()
    
    var body: some View {
        MapViewReader { mapProxy in
            MapView(map: model.map, viewpoint: viewpoint)
                .overlay(alignment: .center) {
                    if isLoading {
                        ProgressView("Loading...")
                            .padding()
                            .background(.ultraThickMaterial)
                            .cornerRadius(10)
                            .shadow(radius: 50)
                    }
                }
                .task {
                    guard let rasterLayer = model.map.operationalLayers.first as? RasterLayer else {
                        return
                    }
                    do {
                        defer { isLoading = false }
                        // Downloads raster from online service.
                        isLoading = true
                        try await rasterLayer.load()
                        if let center = model.imageServiceRaster.serviceInfo?.fullExtent?.center {
                            viewpoint = Viewpoint(
                                center: center,
                                scale: 25000.0
                            )
                        }
                    } catch {
                        // Presents an error message if the raster fails to load.
                        model.error = error
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
        }
        .errorAlert(presentingError: $model.error)
    }
    
    /// The function returns an array of alert buttons to add to the action sheet.
    /// - Parameter mapProxy: passes proxy to function in button
    /// - Returns: Array of alert buttons
    private func createButtons(mapProxy: MapViewProxy) -> [Alert.Button] {
        var results = [Alert.Button]()
        for key in model.mosaicRulePairs.keys.sorted() {
            results.append(
                Alert.Button.default(Text(key)) {
                    Task {
                        await mosaicRuleSelect(
                            at: key,
                            using: mapProxy
                        )
                    }
                }
            )
        }
        return results
    }
    
    /// Updates the rule selection based on what the user selects and applies it the image raster. At the end it updates the viewpoint
    /// to the center of the new raster display.
    /// - Parameters:
    ///   - selection: selected mosiac rule
    ///   - proxy: the `MapView` proxy
    private func mosaicRuleSelect(at selection: String, using proxy: MapViewProxy) async {
        isLoading = true
        defer { isLoading = false }
        model.imageServiceRaster.mosaicRule = model.mosaicRulePairs[selection]
        if let center = model.imageServiceRaster.serviceInfo?.fullExtent?.center {
            await proxy.setViewpoint(
                Viewpoint(
                    center: center,
                    scale: 25000.0
                )
            )
        }
    }
}

private extension ApplyMosaicRuleToRastersView {
    class Model: ObservableObject {
        /// The error shown in the error alert.
        @Published var error: Error?
        
        /// A map with viewpoint set to Amberg, Germany.
        let map: Map = {
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
        
        /// A service that fetches the raster using image source url.
        let imageServiceRaster = {
            let serviceRaster = ImageServiceRaster(
                url: .imageServiceURL
            )
            serviceRaster.mosaicRule = MosaicRule()
            return serviceRaster
        }()
        
        let mosaicRulePairs: [String: MosaicRule] = {
            // A default mosaic rule object, with mosaic method as objectID which
            // functionally is the same as the none rule in earlier versions.
            let objectIDRule = MosaicRule()
            objectIDRule.mosaicMethod = .objectID
            
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
                "Object ID": objectIDRule,
                "North West": northWestRule,
                "Center": centerRule,
                "By Attribute": byAttributeRule,
                "Lock Raster": lockRasterRule
            ]
        }()
        
        init() {
            let rasterLayer = RasterLayer(raster: imageServiceRaster)
            map.addOperationalLayer(rasterLayer)
        }
    }
}

private extension URL {
    /// This sample uses a raster image service that shows aerial images of Amberg, Germany.
    static let imageServiceURL = URL(string: "https://sampleserver7.arcgisonline.com/server/rest/services/amberg_germany/ImageServer")!
}

#Preview {
    ApplyMosaicRuleToRastersView()
}
