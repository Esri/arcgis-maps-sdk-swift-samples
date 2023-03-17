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
    
    @State private var geodatabase = ServiceGeodatabase(url: .featureService)
    
    @State private var tracingActivity: TracingActivity?
    
    @State private var traceType = UtilityTraceParameters.TraceType.connected
    
    @State private var pointType: PointType = .start
    
    @State private var barriers = [UtilityElement]()
    
    @State private var startingPoints = [UtilityElement]()
    
    /// The overlay on which trace graphics will be drawn.
    private var graphicsOverlay: GraphicsOverlay = {
        let barrierPointSymbol = SimpleMarkerSymbol(
            style: .x,
            color: .red,
            size: 20
        )
        let barrierUniqueValue = UniqueValue(
            description: "Barriers",
            label: PointType.barrier.rawValue,
            symbol: barrierPointSymbol,
            values: [TracingActivity.settingPoints, PointType.barrier]
        )
        let startingPointSymbol = SimpleMarkerSymbol(
            style: .cross,
            color: .green,
            size: 20
        )
        let renderer = UniqueValueRenderer(
            fieldNames: ["TraceLocationType"],
            uniqueValues: [barrierUniqueValue],
            defaultLabel: String(describing: TracingActivity.settingPoints),
            defaultSymbol: startingPointSymbol
        )
        let overlay = GraphicsOverlay()
        overlay.renderer = renderer
        return overlay
    }()
    
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
        barriers.removeAll()
        graphicsOverlay.removeAllGraphics()
        map.operationalLayers.forEach { layer in
            (layer as? FeatureLayer)?.clearSelection()
        }
        pointType = .start
        startingPoints.removeAll()
        traceTask?.cancel()
        tracingActivity = .none
        traceType = .connected
    }
    
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
                MapViewReader { mapViewProxy in
                    MapView(map: map, viewpoint: .initialViewpoint, graphicsOverlays: [graphicsOverlay])
                        .onSingleTapGesture { screenPoint, _ in
                            guard tracingActivity == .settingPoints else { return }
                            Task {
                                let identifyLayerResults = try await mapViewProxy.identifyLayers(
                                    screenPoint: screenPoint,
                                    tolerance: 10
                                )
                                for identifyLayerResult in identifyLayerResults {
                                    identifyLayerResult.geoElements.forEach { geoElement in
                                        if let feature = geoElement as? ArcGISFeature,
                                           let element = network?.makeElement(arcGISFeature: feature) {
                                            switch pointType {
                                            case.barrier:
                                                barriers.append(element)
                                            case .start:
                                                startingPoints.append(element)
                                            }
                                            if let geometry = feature.geometry?.extent.center {
                                                let graphic = Graphic(
                                                    geometry: geometry,
                                                    symbol: SimpleMarkerSymbol(
                                                        style: .cross,
                                                        color: .green,
                                                        size: 20
                                                    )
                                                )
                                                graphicsOverlay.addGraphic(graphic)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .onDisappear {
                            ArcGISEnvironment.authenticationManager.arcGISCredentialStore.removeAll()
                        }
                        .task {
                            try? await ArcGISEnvironment.authenticationManager.arcGISCredentialStore.add(.publicSample)
                            try? await network?.load()
                            try? await geodatabase.load()
                            
                            featureLayers.forEach { url in
                                let featureTable = ServiceFeatureTable(url: url)
                                let layer = FeatureLayer(featureTable: featureTable)
                                
                                if featureTable.serviceLayerID == 3 {
                                    let darkCyan = UIColor(red: 0, green: 0.55, blue: 0.55, alpha: 1)
                                    let mediumVoltageValue = UniqueValue(
                                        description: "N/A",
                                        label: "Medium voltage",
                                        symbol: SimpleLineSymbol(
                                            style: .solid,
                                            color: darkCyan,
                                            width: 3
                                        ),
                                        values: [5]
                                    )
                                    let lowVoltageValue = UniqueValue(
                                        description: "N/A",
                                        label: "Low voltage",
                                        symbol: SimpleLineSymbol(
                                            style: .dash,
                                            color: darkCyan,
                                            width: 3
                                        ),
                                        values: [3]
                                    )
                                    layer.renderer = UniqueValueRenderer(
                                        fieldNames: ["ASSETGROUP"],
                                        uniqueValues: [mediumVoltageValue, lowVoltageValue],
                                        defaultLabel: "",
                                        defaultSymbol: SimpleLineSymbol()
                                    )
                                }
                                
                                map.addOperationalLayer(layer)
                            }
                        }
                }
                traceManager
                    .frame(width: geometryProxy.size.width)
                    .background(.thinMaterial)
            }
        }
    }
    
    @State private var traceTask: Task<(), Never>?
    
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
                .disabled(startingPoints.isEmpty)
            case .settingType:
                Picker("Type", selection: $traceType) {
                    ForEach(supportedTraceTypes, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                Button("Trace") {
                    tracingActivity = .tracing
                    traceTask = Task {
                        do {
                            let parameters = UtilityTraceParameters(
                                traceType: traceType,
                                startingLocations: startingPoints
                            )
                            parameters.addBarriers(barriers)
                            parameters.traceConfiguration = mediumVoltageRadial?.defaultTraceConfiguration
                            let traceResults: [UtilityElementTraceResult]? = try await network?.trace(using: parameters)
                                .filter { $0 is UtilityElementTraceResult }
                                .map { $0 as! UtilityElementTraceResult }
                            
                            for result in traceResults ?? [] {
                                let groups = Dictionary(grouping: result.elements) { $0.networkSource.name }
                                for (networkName, elements) in groups {
                                    guard let layer = self.map.operationalLayers.first(where: { ($0 as? FeatureLayer)?.featureTable?.tableName == networkName }) as? FeatureLayer else { continue }
                                    let features = try await network?.features(for: elements) ?? []
                                    layer.selectFeatures(features)
                                }
                            }
                        } catch {
                            print(error)
                        }
                        tracingActivity = .viewingResults
                    }
                }
            case .tracing:
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding()
                    Button("Cancel", role: .destructive) {
                        reset()
                    }
                }
                
            case .viewingResults:
                Button("Reset", role: .destructive) {
                    reset()
                }
                .padding()
            }
            if tracingActivity == .settingPoints || tracingActivity == .settingType {
                Button("Cancel", role: .destructive) {
                    reset()
                }
            }
        }
    }
}

private extension TraceUtilityNetworkView {
    var electricDistribution: UtilityDomainNetwork? {
        network?.definition?.domainNetwork(named: "ElectricDistribution")
    }
    
    var featureLayers: [URL] {
        return [
            URL.featureService.appendingPathComponent("0"),
            URL.featureService.appendingPathComponent("3")
        ]
    }
    
    var network: UtilityNetwork? {
        map.utilityNetworks.first
    }
    
    var supportedTraceTypes: [UtilityTraceParameters.TraceType] {
        return [.connected, .subnetwork, .upstream, .downstream]
    }
    
    var mediumVoltageRadial: UtilityTier? {
        electricDistribution?.tier(named: "Medium Voltage Radial")
    }
}

private extension UtilityTraceParameters.TraceType {
    var displayName: String {
        String(describing: self).capitalized
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

private extension Viewpoint {
    static var initialViewpoint: Viewpoint {
        .init(
            boundingGeometry: Envelope(
                xMin: -9813547.35557238,
                yMin: 5129980.36635111,
                xMax: -9813185.0602376,
                yMax: 5130215.41254146,
                spatialReference: .webMercator
            )
        )
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
    static var featureService: URL {
        .baseURL.appendingPathComponent("server/rest/services/UtilityNetwork/NapervilleElectric/FeatureServer")
    }
    
    static var baseURL: URL {
        URL(string: "https://sampleserver7.arcgisonline.com")!
    }
    
    static var sampleServer7: URL {
        baseURL.appendingPathComponent("portal/sharing/rest")
    }
}
