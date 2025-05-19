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
                        try await wmsService.load()
                        layerInfos = wmsService.serviceInfo?.layerInfos ?? []
                    } catch {
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
                OutlineGroup(items, children: \.children) { item in
                    var item = item
                    HStack {
                        Text(item.label)
                        Spacer()
                        Button(item.isVisible ? "Hide" : "Show") {
                            print("-- tapped!")
                            item.isVisible.toggle()
                        }
                        .padding(.trailing)
                    }
                    .font(.subheadline)
                }
            }
        }
    }
}

extension BrowseWMSLayersView {
    @Observable
    final class WMSLayerItem: Hashable, Identifiable {
        static func == (lhs: WMSLayerItem, rhs: WMSLayerItem) -> Bool {
            lhs.layerInfo === rhs.layerInfo
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        let layerInfo: WMSLayerInfo
        
        init(layerInfo: WMSLayerInfo) {
            self.layerInfo = layerInfo
        }
        
        var kind: Kind {
            !layerInfo.name.isEmpty ? .display : .container
        }
        
        var id: ObjectIdentifier {
            ObjectIdentifier(layerInfo)
        }
        
        var label: String {
            layerInfo.title
        }
        
        var children: [WMSLayerItem]? {
            layerInfo.sublayerInfos.map(WMSLayerItem.init(layerInfo:))
        }
        
        var isVisible: Bool = false
        
        enum Kind {
            case container
            case display
        }
    }
}

#Preview {
    BrowseWMSLayersView()
}
