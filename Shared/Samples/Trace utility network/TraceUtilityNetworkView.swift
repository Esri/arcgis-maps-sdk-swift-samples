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

import ArcGIS
import SwiftUI

struct TraceUtilityNetworkView: View {
    @State private var map = {
        let map = Map(item: PortalItem.napervilleElectricalNetwork)
        map.basemap = Basemap(style: .arcGISStreetsNight)
        return map
    }()
    
    @State private var tracingActivity: TracingActivity?
    
    @State private var traceConfiguration: UtilityNamedTraceConfiguration!
    
    @State private var pointType: PointType = .start
    
    @State private var showingTraceManager = true
    
    @State private var detent = Detent.medium
    
    enum PointType: String {
        case barrier
        case start
    }
    
    enum TracingActivity {
        case settingPoints
        case settingType
        case tracing
        case viewingResults
    }
    
    func reset() {
        tracingActivity = .none
        pointType = .start
    }
    
    @State private var traceConfigurations = [UtilityNamedTraceConfiguration]()
    
    private var hint: String? {
        switch tracingActivity {
        case .none, .viewingResults:
            return nil
        case .settingPoints:
            return "Tap on the map to add a \(pointType == .start ? "Starting Location" : "Barrier")."
        case .settingType:
            return "Choose the trace type"
        case .tracing:
            return "Tracing..."
        }
    }
    
    var body: some View {
        GeometryReader { geometryProxy in
            VStack(spacing: .zero) {
                if let hint {
                    Text(hint)
                }
                MapView(map: map)
                    .onDisappear {
                        ArcGISEnvironment.authenticationManager.arcGISCredentialStore.removeAll()
                    }
                    .task {
                        try? await ArcGISEnvironment.authenticationManager.arcGISCredentialStore.add(.publicSample)
                        traceConfigurations = (try? await network.queryNamedTraceConfigurations()) ?? []
                        traceConfiguration = traceConfigurations.first
                    }
                traceManager
                    .frame(width: geometryProxy.size.width)
                    .background(.thinMaterial)
            }
        }
    }
    
    var traceManager: some View {
        HStack(spacing: 5) {
            switch tracingActivity {
            case .none:
                Button("Start a new trace") {
                    withAnimation {
                        tracingActivity = .settingPoints
                    }
                }
                .padding()
            case .settingPoints:
                Picker("Add starting points & barriers", selection: $pointType) {
                    Text(PointType.start.rawValue.capitalized)
                        .tag(PointType.start)
                    Text(PointType.barrier.rawValue.capitalized)
                        .tag(PointType.barrier)
                }
                .padding()
                .pickerStyle(.segmented)
                Button("Next") {
                    tracingActivity = .settingType
                }
            case .settingType:
                Picker("Type", selection: $traceConfiguration) {
                    ForEach(traceConfigurations) { configuration in
                        Text(configuration.name)
                            .tag(configuration)
                    }
                }
                Button("Trace") {
                    tracingActivity = .tracing
                }
                .disabled(traceConfiguration == nil)
            case .tracing:
                Text("Please wait")
            case .viewingResults:
                Button("Reset") {
                    reset()
                }
            }
            if tracingActivity == .settingPoints || tracingActivity == .settingType {
                Button("Cancel", role: .destructive) {
                    reset()
                }
            }
        }
    }
}

extension UtilityNamedTraceConfiguration: Hashable {
    public static func == (lhs: UtilityNamedTraceConfiguration, rhs: UtilityNamedTraceConfiguration) -> Bool {
        return lhs.name == rhs.name && lhs.traceType == rhs.traceType && lhs.globalID == rhs.globalID
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(traceType)
        hasher.combine(globalID)
    }
}

extension UtilityNamedTraceConfiguration: Identifiable {}

private extension TraceUtilityNetworkView {
    var network: UtilityNetwork {
        map.utilityNetworks.first!
    }
}

private extension ArcGISCredential {
    static var publicSample: ArcGISCredential {
        get async throws {
            try await TokenCredential.credential(
                for: .sampleServer7,
                username: "viewer01",
                password: "I68VGU^nMurF"
            )
        }
    }
}

private extension Item.ID {
    static var napervilleElectricalNetwork: Item.ID {
        .init("471eb0bf37074b1fbb972b1da70fb310")!
    }
}

private extension PortalItem {
    static var napervilleElectricalNetwork: PortalItem {
        .init(
            portal: .arcGISOnline(connection: .authenticated),
            id: .napervilleElectricalNetwork
        )
    }
}

private extension URL {
    static var sampleServer7: URL {
        URL(string: "https://sampleserver7.arcgisonline.com/portal/sharing/rest")!
    }
}
