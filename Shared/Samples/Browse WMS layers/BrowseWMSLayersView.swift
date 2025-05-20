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

/// A view that allows you to select visibility of WMS layers.
struct BrowseWMSLayersView: View {
    /// The map that we will display the WMS layer on.
    @State private var map = Map(basemapStyle: .arcGISDarkGray)
    
    /// The service we will access to display WMS data.
    @State private var wmsService = WMSService(
        url: URL(string: "https://nowcoast.noaa.gov/geoserver/observations/weather_radar/wms?SERVICE=WMS&REQUEST=GetCapabilities")!
    )
    
    /// The error, if any, that occurred.
    @State private var error: Error?
    
    /// The selected visible layers to display in the `WMSLayer`.
    @State private var selection: [WMSLayerModel] = []
    
    /// Models that allow us represent WMS layer infos.
    @State private var layerModels: [WMSLayerModel] = []
    
    /// A Boolean value indicating if the layer visibility list is showing.
    @State private var isListPresented = false
    
    var body: some View {
        MapView(map: map)
            .task {
                do {
                    // Load the WMS service, access the layer infos, and turn
                    // them into models.
                    try await wmsService.load()
                    let layerInfos = wmsService.serviceInfo?.layerInfos ?? []
                    layerModels = layerInfos.map(WMSLayerModel.init(layerInfo:))
                } catch {
                    self.error = error
                }
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button("Layer Visibility") {
                        isListPresented.toggle()
                    }
                    .disabled(layerModels.isEmpty)
                    .popover(isPresented: $isListPresented) {
                        NavigationStack {
                            WMSLayerListView(models: layerModels, selection: $selection)
                                .navigationBarTitleDisplayMode(.inline)
                                .navigationTitle("Layer Visibility")
                                .presentationDetents([.medium])
                                .frame(idealWidth: 320, idealHeight: 380)
                                .toolbar {
                                    ToolbarItem(placement: .topBarTrailing) {
                                        Button("Done") {
                                            isListPresented.toggle()
                                        }
                                    }
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
    /// A view that displays the layers and sublayers in a hierarchical list.
    struct WMSLayerListView: View {
        /// The models to display in the list.
        let models: [WMSLayerModel]
        
        /// The selected models that represent layer infos that we will display
        /// in the `WMSLayer` on the map.
        @Binding var selection: [WMSLayerModel]
        
        var body: some View {
            List(models) { model in
                OutlineGroup(models, children: \.children) { model in
                    HStack {
                        Text(model.layerInfo.title)
                        Spacer()
                        if model.kind == .display {
                            Button {
                                model.isVisible.toggle()
                            } label: {
                                Image(
                                    systemName: model.isVisible || model.isParentVisible ? "eye" : "eye.slash"
                                )
                            }
                            .buttonStyle(.borderless)
                            // Disable the button if the parent is visible because
                            // the sublayer will always display in that case.
                            .disabled(model.isParentVisible)
                            .padding(.trailing)
                        }
                    }
                    .font(.subheadline)
                    .animation(.default, value: model.isVisible)
                    .onChange(of: model.isVisible) { updateSelection() }
                }
            }
            .listStyle(.plain)
        }
        
        /// Updates the selection for given `isVisible`.
        private func updateSelection() {
            func visibleItems(startingWith model: WMSLayerModel) -> [WMSLayerModel] {
                // If the starting one is visible, return that only because
                // child visibility doesn't matter when the parent is visible.
                guard !model.isVisible else { return [model] }
                guard let children = model.children else { return [] }
                return children.flatMap { visibleItems(startingWith: $0) }
            }
            
            selection = models.flatMap { visibleItems(startingWith: $0) }
        }
    }
}

extension BrowseWMSLayersView {
    /// The model for a WMS layer info.
    @Observable
    final class WMSLayerModel: Equatable, Identifiable {
        /// The layer info that this model wraps.
        let layerInfo: WMSLayerInfo
        
        /// Creates a model with a given WMS layer info.
        init(layerInfo: WMSLayerInfo) {
            self.layerInfo = layerInfo
            if !layerInfo.sublayerInfos.isEmpty {
                children = layerInfo.sublayerInfos.map(WMSLayerModel.init(layerInfo:))
            } else {
                children = nil
            }
        }
        
        /// The kind of layer info.
        var kind: Kind {
            // If the WMS layer does not have a name but has a title,
            // it is just a category for other sublayers.
            layerInfo.name.isEmpty ? .container : .display
        }
        
        /// The child layer models.
        let children: [WMSLayerModel]?
        
        /// A Boolean value indicating if the parent is visible.
        var isParentVisible = false
        
        /// A Boolean value indicating if the layer is visible.
        var isVisible = false {
            didSet {
                // Update the children's `isParentVisible` property.
                children?.forEach { $0.isParentVisible = isVisible }
            }
        }
        
        static func == (lhs: WMSLayerModel, rhs: WMSLayerModel) -> Bool {
            lhs.layerInfo === rhs.layerInfo
        }
    }
}

extension BrowseWMSLayersView.WMSLayerModel {
    /// The kind of WMS layer info.
    enum Kind {
        /// A layer info that is just a category for other sublayers.
        case container
        /// A layer info that can be displayed.
        case display
    }
}

#Preview {
    BrowseWMSLayersView()
}
