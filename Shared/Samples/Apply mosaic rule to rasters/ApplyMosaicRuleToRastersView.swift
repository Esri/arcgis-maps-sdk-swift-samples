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

struct ApplyMosaicRuleToRastersView: View {
    /// The current draw status of the map.
    @State private var currentDrawStatus: DrawStatus = .inProgress
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    /// The data model for the sample.
    @StateObject private var model = Model()
    
    /// Holds the reference to the currently selected rule.
    @State private var ruleSelection: RuleSelection = .objectID
    
    var body: some View {
        MapViewReader { mapProxy in
            MapView(map: model.map)
                .onDrawStatusChanged { drawStatus in
                    // Updates the state when the map's draw status changes.
                    withAnimation {
                        currentDrawStatus = drawStatus
                    }
                }
                .overlay(alignment: .center) {
                    if currentDrawStatus == .inProgress {
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
                        // Downloads raster from online service.
                        try await rasterLayer.load()
                        await mapProxy.setViewpoint(
                            Viewpoint(
                                center: model.imageServiceRasterCenter,
                                scale: 25000
                            )
                        )
                    } catch {
                        self.error = error
                    }
                }
                .toolbar {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Picker("Mosiac Rules", selection: $ruleSelection) {
                            ForEach(RuleSelection.allCases, id: \.self) { rule in
                                Text(rule.label)
                            }
                        }
                        .task(id: ruleSelection) {
                            model.imageServiceRaster.mosaicRule = ruleSelection.rule
                            await mapProxy.setViewpoint(
                                Viewpoint(
                                    center: model.imageServiceRasterCenter,
                                    scale: 25000
                                )
                            )
                        }
                        .pickerStyle(.automatic)
                    }
                }
        }
        .errorAlert(presentingError: $error)
    }
}

private enum RuleSelection: CaseIterable, Equatable {
    case objectID, northWest, center, byAttribute, lockRaster
    
    /// The string to be displayed for each `RuleSelection` option.
    var label: String {
        switch self {
        case .objectID: "Object ID"
        case .northWest: "North West"
        case .center: "Center"
        case .byAttribute: "By Attribute"
        case .lockRaster: "Lock Raster"
        }
    }
    
    /// For the selected rule type it creates a new `MosiacRule`
    /// and applies the selected and attributes.
    var rule: MosaicRule {
        let mosaicRule = MosaicRule()
        switch self {
        case .objectID:
            // The default mosaic method is objectID which
            // functionally is the same as the none rule in earlier versions.
            mosaicRule.mosaicMethod = .objectID
        case .northWest:
            // Sets the mosaic rule method to northwest method and sets operation
            // to first.
            mosaicRule.mosaicMethod = .northwest
            mosaicRule.mosaicOperation = .first
        case .center:
            // Sets the mosaic method to center and uses blend operation.
            mosaicRule.mosaicMethod = .center
            mosaicRule.mosaicOperation = .blend
        case .byAttribute:
            // Sets the mosaic method to attribute and sorts on "OBJECTID"
            // field of the service.
            mosaicRule.mosaicMethod = .attribute
            mosaicRule.sortField = "OBJECTID"
        case .lockRaster:
            // Sets the mosaic method to lockRaster method and locks 3 image rasters.
            mosaicRule.mosaicMethod = .lockRaster
            mosaicRule.addLockRasterIDs([1, 7, 12])
        }
        return mosaicRule
    }
}

private extension ApplyMosaicRuleToRastersView {
    @MainActor
    class Model: ObservableObject {
        /// A map with a topographic style.
        let map: Map = {
            let map = Map(basemapStyle: .arcGISTopographic)
            return map
        }()
        
        /// A service that fetches the raster using image source url.
        let imageServiceRaster: ImageServiceRaster = {
            let serviceRaster = ImageServiceRaster(
                url: .imageServiceURL
            )
            serviceRaster.mosaicRule = MosaicRule()
            return serviceRaster
        }()
        
        /// A computed property returns center of raster so that map recenters on rule change.
        var imageServiceRasterCenter: Point {
            imageServiceRaster.serviceInfo?.fullExtent?.center ?? Point(x: 0, y: 0)
        }
        
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
    NavigationStack {
        ApplyMosaicRuleToRastersView()
    }
}
