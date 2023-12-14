// Copyright 2023 Esri
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

import SwiftUI
import ArcGIS

struct AddDynamicEntityLayerView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// A Boolean value indicating whether the settings view should be presented.
    @State private var isShowingSettings = false
    
    /// The initial viewpoint for the map.
    @State private var viewpoint = Viewpoint(
        center: Point(x: -12452361.486, y: 4949774.965),
        scale: 200_000
    )
    
    /// The callout placement.
    @State private var placement: CalloutPlacement?
    
    /// A Boolean value indicating if the stream service is connected.
    var isConnected: Bool {
        model.streamService.connectionStatus == .connected
    }
    
    var body: some View {
        MapViewReader { proxy in
            MapView(map: model.map, viewpoint: viewpoint)
                .callout(placement: $placement) { placement in
                    VehicleCallout(dynamicEntity: placement.geoElement as! DynamicEntity)
                }
                .onSingleTapGesture { screenPoint, _ in
                    placement = nil
                    Task {
                        guard let result = try? await proxy.identify(on: model.dynamicEntityLayer, screenPoint: screenPoint, tolerance: 12),
                              let observation = result.geoElements.first as? DynamicEntityObservation,
                              let entity = observation.dynamicEntity
                        else {
                            return
                        }
                        placement = .geoElement(entity)
                    }
                }
                .toolbar {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button(isConnected ? "Disconnect" : "Connect") {
                            Task {
                                if isConnected {
                                    await model.streamService.disconnect()
                                } else {
                                    try? await model.streamService.connect()
                                }
                            }
                        }
                        Spacer()
                        settingsButton
                    }
                }
                .overlay(alignment: .top) {
                    HStack {
                        Text("Status:")
                        Text(model.connectionStatus)
                            .italic()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(.thinMaterial, ignoresSafeAreaEdges: .horizontal)
                }
                .task {
                    // This will update `connectionStatus` when the stream service
                    // connection status changes.
                    for await status in model.streamService.$connectionStatus {
                        model.connectionStatus = status.description
                    }
                }
        }
    }
    
    @ViewBuilder private var settingsButton: some View {
        let button = Button("Dynamic Entity Settings") {
            isShowingSettings = true
        }
        let settingsView = SettingsView(model: model, calloutPlacement: $placement)
        
        if #available(iOS 16, *) {
            button
                .popover(isPresented: $isShowingSettings, arrowEdge: .bottom) {
                    settingsView
                        .presentationDetents([.fraction(0.5)])
#if targetEnvironment(macCatalyst)
                        .frame(minWidth: 300, minHeight: 270)
#else
                        .frame(minWidth: 320, minHeight: 390)
#endif
                }
        } else {
            button
                .sheet(isPresented: $isShowingSettings, detents: [.medium]) {
                    settingsView
                }
        }
    }
}

#Preview {
    NavigationView {
        AddDynamicEntityLayerView()
    }
}
