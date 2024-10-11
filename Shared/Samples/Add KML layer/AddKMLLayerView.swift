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

struct AddKMLLayerView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// The viewpoint used to update the map view.
    @State private var viewpoint: Viewpoint?
    
    /// The KML layer source selected by the picker.
    @State private var selectedLayerSource = KMLLayerSource.url
    
    var body: some View {
        MapView(map: model.map, viewpoint: viewpoint)
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Picker("KML Layer Source", selection: $selectedLayerSource) {
                        ForEach(KMLLayerSource.allCases, id: \.self) { source in
                            Text(source.label)
                        }
                    }
                    .onChange(of: selectedLayerSource, perform: setKMLLayer(forSource:))
                }
            }
            .task {
                // Loads all the KML layers when the sample opens.
                let kmlLayers = [model.urlLayer, model.localFileLayer, model.portalItemLayer]
                await kmlLayers.load()
                
                setKMLLayer(forSource: selectedLayerSource)
            }
    }
    
    /// Sets a KML layer on the map.
    /// - Parameter source: The source that was used to create the KML layer.
    private func setKMLLayer(forSource source: KMLLayerSource) {
        let kmlLayer = switch source {
        case .url: model.urlLayer
        case .localFile: model.localFileLayer
        case .portalItem: model.portalItemLayer
        }
        
        // Replaces the current KML layer on the map.
        model.map.removeAllOperationalLayers()
        model.map.addOperationalLayer(kmlLayer)
        
        // Zooms the map view's viewpoint to the layer.
        guard let layerExtent = kmlLayer.fullExtent else { return }
        let expandedExtent = layerExtent.withBuilder { $0.expand(by: 1.1) }
        viewpoint = Viewpoint(boundingGeometry: expandedExtent)
    }
}

private extension AddKMLLayerView {
    /// The view model that contains the map and KML layers.
    final class Model: ObservableObject {
        /// A map with a dark grey basemap.
        let map = Map(basemapStyle: .arcGISDarkGrayBase)
        
        /// A KML layer created from a web URL.
        let urlLayer: KMLLayer = {
            let url = URL(string: "https://www.wpc.ncep.noaa.gov/kml/noaa_chart/WPC_Day1_SigWx.kml")!
            let kmlDataset = KMLDataset(url: url)
            return KMLLayer(dataset: kmlDataset)
        }()
        
        /// A KML layer created from a local file in the bundle.
        let localFileLayer: KMLLayer = {
            let kmlDataset = KMLDataset(name: "US_State_Capitals", bundle: .main)!
            return KMLLayer(dataset: kmlDataset)
        }()
        
        /// A KML layer created from a portal item.
        let portalItemLayer: KMLLayer = {
            let portalID = PortalItem.ID("9fe0b1bfdcd64c83bd77ea0452c76253")!
            let portalItem = PortalItem(portal: .arcGISOnline(connection: .anonymous), id: portalID)
            return KMLLayer(item: portalItem)
        }()
    }
    
    /// A source that was used to create a KML layer.
    enum KMLLayerSource: CaseIterable {
        case url, localFile, portalItem
        
        /// A human-readable label for the KML layer source.
        var label: String {
            switch self {
            case .url: "URL"
            case .localFile: "Local File"
            case .portalItem: "Portal Item"
            }
        }
    }
}
