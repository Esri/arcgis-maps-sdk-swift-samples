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

@MainActor
struct AddWMTSLayerView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// The WMTS layer source selected by the picker.
    @State private var selectedLayerSource = WMTSLayerSource.wmtsLayerInfo
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    var body: some View {
        MapView(map: model.map)
            .task {
                do {
                    try await model.loadService()
                    model.setWMTSLayer(for: selectedLayerSource)
                } catch {
                    self.error = error
                }
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Picker("WMTS Layer", selection: $selectedLayerSource) {
                        ForEach(WMTSLayerSource.allCases, id: \.self) { source in
                            Text(source.label)
                        }
                    }
                    .onChange(of: selectedLayerSource) {
                        model.setWMTSLayer(for: selectedLayerSource)
                    }
                }
            }
            .errorAlert(presentingError: $error)
    }
}

private extension AddWMTSLayerView {
    /// The view model that contains the map and WMTS layer.
    @MainActor
    final class Model: ObservableObject {
        /// A map with no specified style.
        private(set) var map = Map()
        
        /// The web map tile service.
        private let service = WMTSService(url: URL(string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/WorldTimeZones/MapServer/WMTS")!)
        
        /// The service URL.
        private var serviceURL: URL {
            service.url
        }
        
        /// Loads the web map tile service.
        func loadService() async throws {
            do {
                try await service.load()
            } catch {
                throw error
            }
        }
        
        /// Sets a WMTS layer on the map.
        /// - Parameter source: The source that was used to create the WMTS layer.
        func setWMTSLayer(for source: WMTSLayerSource) {
            map.removeAllOperationalLayers()
            switch source {
            case .url:
                // Create a WMTS layer using the service URL and layer ID.
                let wmtsLayer = WMTSLayer(url: serviceURL, layerID: "WorldTimeZones")
                map.addOperationalLayer(wmtsLayer)
            case .wmtsLayerInfo:
                // Create a WMTS layer using a WMTS layer info.
                let serviceInfo = service.serviceInfo
                let layerInfos = serviceInfo!.layerInfos
                let layerInfo = layerInfos.first!
                let wmtsLayer = WMTSLayer(layerInfo: layerInfo)
                map.addOperationalLayer(wmtsLayer)
            }
        }
    }
}

private extension AddWMTSLayerView {
    /// A source that was used to create a WMTS layer.
    enum WMTSLayerSource: CaseIterable {
        case wmtsLayerInfo, url
        
        /// A human-readable label for the WMTS layer source.
        var label: String {
            switch self {
            case .wmtsLayerInfo: "WMTS Layer Info"
            case .url: "URL"
            }
        }
    }
}

#Preview {
    AddWMTSLayerView()
}
