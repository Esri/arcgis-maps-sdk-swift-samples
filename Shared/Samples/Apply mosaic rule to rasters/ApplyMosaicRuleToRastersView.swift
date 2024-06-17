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
    /// The error shown in the error alert.
    @State var error: Error?
    
    /// A Boolean value indicating whether a operation is in progress.
    @State private var isLoading = false
    
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
                    defer { isLoading = false }
                    do {
                        isLoading = true
                        // Downloads raster from online service
                        try await rasterLayer.load()
                        
                        await mapProxy.setViewpoint(
                            Viewpoint(
                                center: model.getCenter(),
                                scale: 25000.0
                            )
                        )
                    } catch {
                        self.error = error
                    }
                }
                .toolbar {
                    ToolbarItemGroup(placement: .principal) {
                        Picker("Rule Pairs", selection: $model.rulePair) {
                            ForEach(RulePairs.allCases, id: \.self) { rule in
                                Text(rule.label)
                            }
                        }
                        .onChange(of: model.rulePair) { rulePair in
                            Task {
                                isLoading = true
                                model.updateMosiacRule(with: rulePair)
                                await mapProxy.setViewpoint(
                                    Viewpoint(
                                        center: model.getCenter(),
                                        scale: 25000.0
                                    )
                                )
                                isLoading = false
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
        }
        .errorAlert(presentingError: $error)
    }
}

private enum RulePairs: CaseIterable, Equatable {
    static var allCases: [RulePairs] {
        return [.objectID, .northWest, .center, .byAttribute, lockRaster]
    }
    
    case objectID, northWest, center, byAttribute, lockRaster
    
    @available(*, unavailable)
    case all
    
    var label: String {
        switch self {
        case .objectID:
            return "Object ID"
        case .northWest:
            return "North West"
        case .center:
            return "Center"
        case .byAttribute:
            return "By Attribute"
        case .lockRaster:
            return "Lock Raster"
        }
    }
    
    static func == (lhs: RulePairs, rhs: RulePairs) -> Bool {
        return lhs.label == rhs.label
    }
}

private extension ApplyMosaicRuleToRastersView {
    @MainActor
    class Model: ObservableObject {
        @Published var rulePair: RulePairs = .objectID
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
        
        static let mosaicRulePairs: [String: MosaicRule] = {
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
        
        func updateMosiacRule(with rulePair: RulePairs) {
            imageServiceRaster.mosaicRule = Model.mosaicRulePairs[rulePair.label]
        }
        
        func getCenter() -> Point {
            return imageServiceRaster.serviceInfo?.fullExtent?.center ?? Point(x: 0, y: 0)
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
