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
    
    @State private var selection: [WMSLayerItem] = []
    
    @State private var layerModels: [WMSLayerItem] = []
    
    @State private var isListPresented = false
    
    var body: some View {
        MapViewReader { mapViewProxy in
            MapView(map: map)
                .task {
                    do {
                        try await wmsService.load()
                        let layerInfos = wmsService.serviceInfo?.layerInfos ?? []
                        layerModels = layerInfos.map(WMSLayerItem.init(layerInfo:))
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
                WMSLayerListView(items: layerModels, selection: $selection)
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
        .onChange(of: selection) {
            map.removeAllOperationalLayers()
            guard !selection.isEmpty else { return }
            let wmsLayer = WMSLayer(layerInfos: selection.map(\.layerInfo))
            map.addOperationalLayer(wmsLayer)
        }
        .errorAlert(presentingError: $error)
    }
}

extension BrowseWMSLayersView {
    struct WMSLayerListView: View {
        @State var items: [WMSLayerItem]
        @Binding var selection: [WMSLayerItem]
        
        var body: some View {
            List(items) { item in
                OutlineGroup(items, children: \.children) { item in
                    HStack {
                        Text(item.label)
                        Spacer()
                        if item.kind == .display {
                            Button {
                                item.isVisible.toggle()
                            } label: {
                                Image(systemName: item.isVisible ? "eye" : "eye.slash")
                            }
                            .padding(.trailing)
                        }
                    }
                    .font(.subheadline)
                    .animation(.default, value: item.isVisible)
                    .onChange(of: item.isVisible) { updateVisibility() }
                }
            }
        }
        
        private func updateVisibility() {
            func visibleItems(startingWith item: WMSLayerItem) -> [WMSLayerItem] {
                let thisOne = item.isVisible ? [item] : []
                guard let children = item.children else { return thisOne }
                let visibleChildren = children.flatMap { visibleItems(startingWith: $0) }
                return thisOne + visibleChildren
            }
            
            selection = items.flatMap { visibleItems(startingWith: $0) }
            print("-- selection: \(selection)")
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
            children = layerInfo.sublayerInfos.map(WMSLayerItem.init(layerInfo:))
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
        
        let children: [WMSLayerItem]?
        
        var isVisible: Bool = false
    }
}

extension BrowseWMSLayersView.WMSLayerItem {
    enum Kind {
        case container
        case display
    }
}

#Preview {
    BrowseWMSLayersView()
}
