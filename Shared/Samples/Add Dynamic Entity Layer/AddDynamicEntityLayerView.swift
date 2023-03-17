// Copyright 2022 Esri
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
    @State var isShowingSettings = false
    
    /// The initial viewpoint for the map.
    @State var viewpoint = Viewpoint(
        center: Point(x: -12452361.48631679, y: 4949774.965107439),
        scale: 200_000
    )
    
    /// A Boolean value indicating if the stream service is connected.
    var isConnected: Bool {
        model.streamService.connectionStatus == .connected
    }
    
    var body: some View {
        // Creates a map view to display the map.
        MapView(map: model.map, viewpoint: viewpoint)
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button(isConnected ? "Disconnect" : "Connect") {
                        Task {
                            if isConnected {
                                try? await model.streamService.disconnect()
                            } else {
                                try? await model.streamService.connect()
                            }
                        }
                    }
                    Spacer()
                    Button("Dynamic Entity Settings") {
                        isShowingSettings = true
                    }
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
            .sheet(isPresented: $isShowingSettings, detents: [.medium], dragIndicatorVisibility: .visible) {
                SettingsView()
                    .environmentObject(model)
            }
    }
}

extension AddDynamicEntityLayerView {
    private struct SettingsView: View {
        /// The view model for the sample.
        @EnvironmentObject private var model: Model
        
        var body: some View {
            List {
                Section("Track display properties") {
                    Toggle("Track lines", isOn: $model.showsTrackLine)
                    Toggle("Previous observations", isOn: $model.showsPreviousObservations)
                }
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                
                Section("Observations") {
                    VStack {
                        Text("Observations per track: \(model.maximumObservations.formatted())")
                        /// The range of possible z-values. The z-value range is 0 to 140 meters in this sample.
                        Slider(value: $model.maximumObservations, in: model.maxObservationRange, step: 1) {
                            Text("Observations")
                        } minimumValueLabel: {
                            Text(model.maxObservationRange.lowerBound.formatted())
                        } maximumValueLabel: {
                            Text(model.maxObservationRange.upperBound.formatted())
                        }
                    }
                    HStack {
                        Spacer()
                        Button("Purge all observations") {
                            Task {
                                try? await model.streamService.purgeAll()
                            }
                        }
                        Spacer()
                    }
                }
            }
        }
    }
}

private extension AddDynamicEntityLayerView {
    /// The model used to store the geo model and other expensive objects
    /// used in this view.
    class Model: ObservableObject {
        /// A map with a streets basemap style.
        let map = Map(basemapStyle: .arcGISStreets)
        
        /// The data source for the dynamic entity layer.
        var streamService: ArcGISStreamService = {
            let streamService = ArcGISStreamService(url: .streamService)
            
            let filter = ArcGISStreamServiceFilter()
            filter.whereClause = "speed > 0"
            streamService.filter = filter
            
            streamService.purgeOptions.maximumDuration = TimeInterval(5 * 60)
            return streamService
        }()
        
        /// The layer displaying the dynamic entities on the map.
        var dynamicEntityLayer: DynamicEntityLayer
        
        /// A Boolean value indicating whether track lines should be displayed.
        @Published var showsTrackLine: Bool {
            didSet {
                dynamicEntityLayer.trackDisplayProperties.showsTrackLine = showsTrackLine
            }
        }
        
        /// A Boolean value indicating whether previous observations should be displayed.
        @Published var showsPreviousObservations: Bool {
            didSet {
                dynamicEntityLayer.trackDisplayProperties.showsPreviousObservations = showsPreviousObservations
            }
        }
        
        /// The maximum number of previous observations to display.
        @Published var maximumObservations: CGFloat {
            didSet {
                dynamicEntityLayer.trackDisplayProperties.maximumObservations = Int(maximumObservations)
            }
        }
        
        // The maximum observations range.
        // Used by Slider, which requires CGFloat values.
        let maxObservationRange = CGFloat(0)...CGFloat(16)
        
        /// The stream service connection status.
        @Published var connectionStatus: String

        init() {
            // Create the dynamic entity layer
            dynamicEntityLayer = DynamicEntityLayer(dataSource: streamService)
            
            // Initialize properties from the dynamic entity layer and stream service.
            showsTrackLine = dynamicEntityLayer.trackDisplayProperties.showsTrackLine
            showsPreviousObservations = dynamicEntityLayer.trackDisplayProperties.showsPreviousObservations
            maximumObservations = CGFloat(dynamicEntityLayer.trackDisplayProperties.maximumObservations)
            connectionStatus = streamService.connectionStatus.description
            
            Task {
                // This will update `connectionStatus` when the stream service
                // connection status changes.
                for await status in streamService.$connectionStatus {
                    DispatchQueue.main.async { [weak self] in
                        self?.connectionStatus = status.description
                    }
                }
            }
            
            // Add the dynamic entity layer to the map's operation layers array.
            map.addOperationalLayer(dynamicEntityLayer)
        }
    }
}

private extension URL {
    static let streamService = URL(
        string: "https://realtimegis2016.esri.com:6443/arcgis/rest/services/SandyVehicles/StreamServer"
    )!
}

extension ConnectionStatus: CustomStringConvertible {
    /// A user-friendly string for ConnectionStatus.
    public var description: String {
        switch self {
        case .connecting:
            return "Connecting"
        case .connected:
            return "Connected"
        case .disconnected:
            return "Disconnected"
        case .failed:
            return "Failed"
        }
    }
}
