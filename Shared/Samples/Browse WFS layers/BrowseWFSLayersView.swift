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

/// The initial view of the Browse WFS Layers sample.
struct BrowseWFSLayersView: View {
    /// The URL of the service to load.
    @State private var serviceURL = URL(string: "https://dservices2.arcgis.com/ZQgQTuoyBrtmoGdP/arcgis/services/Seattle_Downtown_Features/WFSServer?service=wfs&request=getcapabilities")!
    /// A Boolean value indicating whether the service view is pushed on the
    /// navigation stack.
    @State private var isServiceViewPresented = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        "WFS Service",
                        value: $serviceURL,
                        format: .url,
                        prompt: Text("WFS Service URL")
                    )
                    Button("Load") {
                        isServiceViewPresented = true
                    }
                    .foregroundStyle(.accent)
                    .containerRelativeFrame(.horizontal)
                    .multilineTextAlignment(.center)
                }
            }
            .navigationDestination(isPresented: $isServiceViewPresented) {
                WFSServiceView(serviceURL: serviceURL)
            }
        }
    }
}

/// A view that loads a WFS service and lists its layers.
private struct WFSServiceView: View {
    /// The URL of the WFS service to load.
    let serviceURL: URL
    
    @Environment(\.dismiss) private var dismiss
    
    /// The loaded WFS service.
    @State private var service: WFSService?
    /// The error if the service failed to load, otherwise `nil`.
    @State private var serviceLoadError: Error?
    /// A Boolean value indicating whether the service failed to load.
    @State private var serviceLoadDidFail = false
    
    var body: some View {
        if let serviceInfo = service?.serviceInfo {
            Form {
                Section("Layers") {
                    ForEach(serviceInfo.layerInfos, id: \.name) { layerInfo in
                        NavigationLink(layerInfo.title) {
                            WFSServiceLayerView(layerInfo: layerInfo)
                        }
                    }
                }
            }
            .navigationTitle(serviceInfo.title)
        } else {
            ProgressView()
                .navigationTitle("Loading Service")
                .task {
                    let service = WFSService(url: serviceURL)
                    do {
                        try await withTaskCancellationHandler {
                            try await service.load()
                        } onCancel: {
                            service.cancelLoad()
                        }
                        self.service = service
                    } catch {
                        serviceLoadError = error
                    }
                }
                .alert("Error", isPresented: $serviceLoadDidFail, presenting: serviceLoadError) { _ in
                    Button("OK") {
                        dismiss()
                    }
                } message: { error in
                    Text(String(reflecting: error))
                }
        }
    }
}

/// A view that displays a layer of a WFS service.
private struct WFSServiceLayerView: View {
    /// The metadata of the layer to display.
    let layerInfo: WFSLayerInfo
    
    /// The map that displays the layer.
    @State private var map = Map(basemapStyle: .arcGISImageryStandard)
    /// The area of the map to display.
    @State private var viewpoint: Viewpoint?
    /// The error if the populate operation failed, otherwise `nil`.
    @State private var populateError: Error?
    /// A Boolean value indicating whether a query operation is in progress.
    @State private var isQuerying = false
    /// A Boolean value indicating whether the axis order should be swapped.
    @State private var swapAxisOrder = false
    
    var body: some View {
        MapView(map: map, viewpoint: viewpoint)
            .onViewpointChanged(kind: .boundingGeometry) { newViewpoint in
                viewpoint = newViewpoint
            }
            .onAppear {
                if let extent = layerInfo.extent {
                    viewpoint = Viewpoint(boundingGeometry: extent)
                }
            }
            .task(id: swapAxisOrder) {
                map.removeAllOperationalLayers()
                let featureTable = WFSFeatureTable(layerInfo: layerInfo)
                // Sets the feature request mode to 'manualCache'. In this mode,
                // you must manually populate the table - panning and zooming
                // won't request features automatically.
                featureTable.featureRequestMode = .manualCache
                featureTable.axisOrder = if swapAxisOrder {
                    .swap
                } else {
                    .noSwap
                }
                do {
                    isQuerying = true
                    _ = try await featureTable.populateFromService(using: nil, clearCache: false, outFields: [])
                    let featureLayer = FeatureLayer(featureTable: featureTable)
                    if let geometryType = featureTable.geometryType,
                       let renderer = renderer(for: geometryType) {
                        featureLayer.renderer = renderer
                    }
                    map.addOperationalLayer(featureLayer)
                    isQuerying = false
                } catch is CancellationError {
                    // Do nothing.
                } catch {
                    self.populateError = error
                    isQuerying = false
                }
            }
            .navigationTitle(layerInfo.title)
            .toolbar {
                if isQuerying {
                    ToolbarItem(placement: .topBarTrailing) {
                        ProgressView()
                            .progressViewStyle(.circular)
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    Toggle(isOn: $swapAxisOrder) {
                        Text("Swap Axis Order")
                        Text("Try if nothing appears after load.")
                    }
                    .toggleStyle(.switch)
                }
            }
            .errorAlert(presentingError: $populateError)
    }
    
    /// Returns a renderer for the given geometry type.
    /// - Parameter geometryType: The type of geometry to be rendered.
    /// - Returns: A renderer.
    func renderer(for geometryType: Geometry.Type) -> Renderer? {
        let symbol: Symbol? = switch geometryType {
        case is Point.Type, is Multipoint.Type:
            SimpleMarkerSymbol(style: .circle, color: .blue, size: 4)
        case is Envelope.Type, is ArcGIS.Polygon.Type:
            SimpleFillSymbol(style: .solid, color: .blue)
        case is Polyline.Type:
            SimpleLineSymbol(style: .solid, color: .blue, width: 1)
        default:
            nil
        }
        return symbol.map(SimpleRenderer.init(symbol:))
    }
}
