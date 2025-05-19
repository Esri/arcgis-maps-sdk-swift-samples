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
    
    @State private var selection: [WMSLayerModel] = []
    
    @State private var layerModels: [WMSLayerModel] = []
    
    @State private var isListPresented = false
    
    var body: some View {
        MapView(map: map)
            .task {
                do {
                    try await wmsService.load()
                    let layerInfos = wmsService.serviceInfo?.layerInfos ?? []
                    layerModels = layerInfos.map(WMSLayerModel.init(layerInfo:))
                } catch {
                    self.error = error
                }
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button("Layer List") {
                        isListPresented = true
                    }
                    .disabled(layerModels.isEmpty)
                }
            }
            .popover(isPresented: $isListPresented) {
                NavigationStack {
                    WMSLayerListView(models: layerModels, selection: $selection)
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
        @State var models: [WMSLayerModel]
        @Binding var selection: [WMSLayerModel]
        
        var body: some View {
            List(models) { item in
                OutlineGroup(models, children: \.children) { item in
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
            func visibleItems(startingWith model: WMSLayerModel) -> [WMSLayerModel] {
                // If the starting one is visible, return that only because
                // child visibility doesn't matter when the parent is visible.
                guard !model.isVisible else { return [model] }
                guard let children = model.children else { return [] }
                return children.flatMap { visibleItems(startingWith: $0) }
            }
            
            selection = models.flatMap { visibleItems(startingWith: $0) }
            print("-- selection: \(selection)")
        }
    }
}

extension BrowseWMSLayersView {
    @Observable
    final class WMSLayerModel: Hashable, Identifiable {
        static func == (lhs: WMSLayerModel, rhs: WMSLayerModel) -> Bool {
            lhs.layerInfo === rhs.layerInfo
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        let layerInfo: WMSLayerInfo
        
        init(layerInfo: WMSLayerInfo) {
            self.layerInfo = layerInfo
            children = layerInfo.sublayerInfos.map(WMSLayerModel.init(layerInfo:))
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
        
        let children: [WMSLayerModel]?
        
        var isVisible: Bool = false
    }
}

extension BrowseWMSLayersView.WMSLayerModel {
    enum Kind {
        case container
        case display
    }
}

#Preview {
    BrowseWMSLayersView()
}
