// Copyright 2025 Esri
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

struct BrowseWMSLayersView: View {
    @State private var map = Map(basemapStyle: .arcGISDarkGray)
    @State private var wmsService = WMSService(url: URL(string: "https://nowcoast.noaa.gov/geoserver/observations/weather_radar/wms?SERVICE=WMS&REQUEST=GetCapabilities")!)
    
    @State private var error: Error?
    
    @State private var selection: WMSLayerInfo?
    
    @State private var layerInfos = [WMSLayerInfo]()
    
    @State private var isListPresented = false
    
    var body: some View {
        MapViewReader { mapViewProxy in
            MapView(map: map)
                .task {
                    do {
                        print("-- loading")
                        try await wmsService.load()
                        if let info = wmsService.serviceInfo {
//                            let layer = WMSLayer(layerInfos: info.layerInfos)
//                            print("-- adding layer, count: \(info.layerInfos.count)")
//                            map.addOperationalLayer(layer)
                            
//                            try await layer.load()
                            
//                            if let layerInfo = info.layerInfos.first {
//                                let layer = WMSLayer(layerInfos: layerInfo.sublayerInfos)
//                                print("-- adding layer, count: \(layerInfo.sublayerInfos.count)")
//                                map.addOperationalLayer(layer)
////                                if let extent = layerInfo.extent {
////                                    print("-- zooming: \(extent)")
////                                    await mapViewProxy.setViewpointGeometry(extent, padding: 50)
////                                }
//                            }
                            
                            layerInfos = info.layerInfos
                            
                            
//                            if let extent = layer.fullExtent {
//                                print("-- zooming: \(extent)")
//                                await mapViewProxy.setViewpointGeometry(extent, padding: 50)
//                            }
                        }
                        //                    for info in wmsService.serviceInfo?.layerInfos {
                        //
                        //                    }
                    } catch {
                        print("-- error: \(error)")
                        self.error = error
                    }
                }
        }
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button("Layer List") {
                    isListPresented = true
                }
            }
        }
        .popover(isPresented: $isListPresented) {
            NavigationStack {
                WMSLayerListView(layerInfos: layerInfos, selection: $selection)
                    .presentationDetents([.medium])
                    .frame(idealWidth: 320, idealHeight: 380)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                isListPresented = false
                            }
                        }
                    }
            }
        }
        .errorAlert(presentingError: $error)
    }
}

extension BrowseWMSLayersView {
    struct WMSLayerListView: View {
        let layerInfos: [WMSLayerInfo]
        @Binding var selection: WMSLayerInfo?
        
        var items: [WMSLayerItem] {
            layerInfos.map(WMSLayerItem.init(layerInfo:))
        }
        
        var body: some View {
            List(items) { item in
                //ItemView(item: item)
                OutlineGroup(items, children: \.children) { item in
                    Text(item.label)
                }
            }
        }
    }
}

//extension BrowseWMSLayersView.WMSLayerListView {
//    struct ItemView: View {
//        let item: WMSLayerItem
//        
//        var body: some View {
//            Group {
//                if item.children.isEmpty {
//                    Text(item.label)
//                } else {
//                    DisclosureGroup(item.label) {
//                        ForEach(item.children) { subItem in
//                            ItemView(item: subItem)
//                        }
//                    }
//                }
//            }
//            .foregroundStyle(item.kind == .display ? .primary : .secondary)
//        }
//    }
//}

struct WMSLayerItem: Hashable, Identifiable {
    static func == (lhs: WMSLayerItem, rhs: WMSLayerItem) -> Bool {
        lhs.layerInfo === rhs.layerInfo
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    let layerInfo: WMSLayerInfo
    
    var kind: Kind {
        !layerInfo.name.isEmpty ? .display : .container
    }
    
    var id: ObjectIdentifier {
        ObjectIdentifier(layerInfo)
    }
    
    var label: String {
        layerInfo.title
//        layerInfo.name
//        !layerInfo.title.isEmpty ? layerInfo.title : layerInfo.name
    }
    
    var children: [WMSLayerItem]? {
        layerInfo.sublayerInfos.map(WMSLayerItem.init(layerInfo:))
    }
    
    enum Kind {
        case container
        case display
    }
}

#Preview {
    BrowseWMSLayersView()
}
