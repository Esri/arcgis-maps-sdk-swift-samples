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
    /// The textual hint shown to the user.
    @State var hint: String?
    
    /// The last element that was added to either the list of starting points or barriers.
    ///
    /// When an element contains more than one terminal, the user should be presented with the
    /// option to select a terminal. Keeping a reference to the last added element provides ease of
    /// access to save the user's choice.
    @State private var lastAddedElement: UtilityElement?
    
    /// The last locations in the screen and map where a tap occurred.
    ///
    /// Monitoring these values allows for an asynchronous identification task when they change.
    @State private var lastSingleTap: (screenPoint: CGPoint, mapPoint: Point)?
    
    /// The view model for the sample.
    @StateObject private var model = TraceUtilityNetworkView.Model()
    
    /// The parameters for the pending trace.
    ///
    /// Important trace information like the trace type, starting points, and barriers is contained
    /// within this value.
    @State private var pendingTraceParameters: UtilityTraceParameters?
    
    /// A Boolean value indicating if the user is selecting a terminal for an element.
    ///
    /// When a utility element has more than one terminal, the user is presented with a menu of the
    /// available terminal names.
    @State private var terminalSelectionIsOpen = false
    
    /// A Boolean value indicating if the user is selecting a trace type.
    @State private var traceTypeSelectionIsOpen = false
    
    /// The current tracing related activity.
    @State private var tracingActivity: TracingActivity?
    
    /// The graphics overlay on which starting point and barrier symbols will be drawn.
    private var points: GraphicsOverlay = {
        let overlay = GraphicsOverlay()
        let barrierUniqueValue = UniqueValue(
            symbol: SimpleMarkerSymbol.barrier,
            values: [PointType.barrier.rawValue]
        )
        overlay.renderer = UniqueValueRenderer(
            fieldNames: [String(describing: PointType.self)],
            uniqueValues: [barrierUniqueValue],
            defaultSymbol: SimpleMarkerSymbol.startingLocation
        )
        return overlay
    }()
    
    // MARK: Enums
    
    /// The types of points used during a utility network trace.
    private enum PointType: String {
        case barrier
        case start
    }
    
    /// The different activities a user will traverse while performing a utility network trace.
    private enum TracingActivity: Equatable {
        case settingPoints(pointType: PointType)
        case settingType
        case tracing
        case viewingResults
    }
    
    // MARK: Methods
    
    /// Adds the provided utility element to the parameters of the pending trace and a corresponding
    /// starting location or barrier graphic to the map.
    /// - Parameters:
    ///   - element: The utility element to be added to the pending trace.
    ///   - point: The location on the map where the element's visual indicator should be added.
    private func add(_ element: UtilityElement, at point: Geometry) {
        guard let pendingTraceParameters,
            case .settingPoints(let pointType) = tracingActivity else { return }
        let graphic = Graphic(
            geometry: point,
            attributes: [String(describing: PointType.self): pointType.rawValue]
        )
        switch pointType {
        case.barrier:
            pendingTraceParameters.addBarrier(element)
        case .start:
            pendingTraceParameters.addStartingLocation(element)
        }
        points.addGraphic(graphic)
        lastAddedElement = element
    }
    
    /// Adds a provided feature to the pending trace.
    ///
    /// For junction features with more than one terminal, the user should be prompted to pick a
    /// terminal. For edge features, the fractional point along the feature's edge should be
    /// computed.
    /// - Parameters:
    ///   - feature: The feature to be added to the pending trace.
    ///   - mapPoint: The location on the map where the feature was discovered. If the feature is a
    ///   junction type, the feature's geometry will be used instead.
    private func add(_ feature: ArcGISFeature, at mapPoint: Point) {
        if let element = network?.makeElement(arcGISFeature: feature),
           let geometry = feature.geometry,
           let table = feature.table as? ArcGISFeatureTable,
           let networkSource = network?.definition?.networkSource(named: table.tableName) {
            switch networkSource.kind {
            case .junction:
                add(element, at: geometry)
                if element.assetType.terminalConfiguration?.terminals.count ?? .zero > 1 {
                    terminalSelectionIsOpen.toggle()
                }
            case .edge:
                if let line = GeometryEngine.makeGeometry(from: geometry, z: nil) as? Polyline {
                    element.fractionAlongEdge = GeometryEngine.polyline(
                        line,
                        fractionalLengthClosestTo: mapPoint,
                        tolerance: -1
                    )
                    updateUserHint(withMessage: String(format: "fractionAlongEdge: %.3f", element.fractionAlongEdge))
                    add(element, at: mapPoint)
                }
            @unknown default:
                return
            }
        }
    }
    
    /// Identifies the first discoverable feature at the provided screen point.
    /// - Parameters:
    ///   - screenPoint: The location on the screen where the identify operation is desired.
    ///   - proxy: The map view proxy to perform the identify operation with.
    /// - Returns: The first discoverable feature or `nil` if none were identified.
    private func identifyFeatureAt(_ screenPoint: CGPoint, with proxy: MapViewProxy) async -> ArcGISFeature? {
        guard let feature = try? await proxy.identifyLayers(
            screenPoint: screenPoint,
            tolerance: 10
        ).first?.geoElements.first as? ArcGISFeature else {
            return nil
        }
        return feature
    }
    
    /// Resets all of the important stateful values for when a trace is cancelled or completed.
    private func reset() {
        model.map.operationalLayers.forEach { ($0 as? FeatureLayer)?.clearSelection() }
        points.removeAllGraphics()
        pendingTraceParameters = nil
        tracingActivity = .none
    }
    
    /// Performs important tasks including adding credentials, loading and adding operational layers.
    private func setup() async {
        do {
            try await ArcGISEnvironment.authenticationManager.arcGISCredentialStore.add(.publicSample)
            try await network?.load()
        } catch {
            hint = "An error occurred while loading the network."
            return
        }
        featureLayerURLs.forEach { url in
            let table = ServiceFeatureTable(url: url)
            let layer = FeatureLayer(featureTable: table)
            if table.serviceLayerID == 3 {
                layer.renderer = UniqueValueRenderer(
                    fieldNames: ["ASSETGROUP"],
                    uniqueValues: [.lowVoltage, .mediumVoltage],
                    defaultSymbol: SimpleLineSymbol()
                )
            }
            model.map.addOperationalLayer(layer)
        }
    }
    
    /// Runs a trace with the pending trace configuration and selects features in the map that
    /// correspond to the element results.
    ///
    /// Note that elements are grouped by network source prior to selection so that all selections
    /// per operational layer can be made at once.
    private func trace() async {
        guard let pendingTraceParameters else { return }
        do {
            let traceResults = try await network?.trace(using: pendingTraceParameters)
                .filter { $0 is UtilityElementTraceResult }
            for result in traceResults as? [UtilityElementTraceResult] ?? [] {
                let groups = Dictionary(grouping: result.elements) { $0.networkSource.name }
                for (networkName, elements) in groups {
                    guard let layer = self.model.map.operationalLayers.first(
                        where: { ($0 as? FeatureLayer)?.featureTable?.tableName == networkName }
                    ) as? FeatureLayer else { continue }
                    let features = try await network?.features(for: elements) ?? []
                    layer.selectFeatures(features)
                }
            }
            tracingActivity = .viewingResults
        } catch {
            tracingActivity = .none
            updateUserHint(withMessage: "An error occurred")
        }
    }
    
    /// Updates the textual user hint. If no message is provided a default hint is used.
    /// - Parameter message: The message to display to the user.
    private func updateUserHint(withMessage message: String? = nil) {
        if let message {
            hint = message
        } else {
            switch tracingActivity {
            case .none:
                hint = ""
            case .settingPoints(let pointType):
                switch pointType {
                case .start:
                    hint = "Tap on the map to add a Start Location."
                case .barrier:
                    hint = "Tap on the map to add a Barrier."
                }
            case .settingType:
                hint = "Choose the trace type"
            case .tracing:
                hint = "Tracing..."
            case .viewingResults:
                hint = "Trace completed."
            }
        }
    }
    
    // MARK: Views
    
    var body: some View {
        GeometryReader { geometryProxy in
            VStack(spacing: .zero) {
                if let hint {
                    Text(hint)
                        .padding([.bottom])
                }
                MapViewReader { mapViewProxy in
                    MapView(map: model.map, viewpoint: .initialViewpoint, graphicsOverlays: [points])
                        .onSingleTapGesture { screenPoint, mapPoint in
                            lastSingleTap = (screenPoint, mapPoint)
                        }
                        .selectionColor(.yellow)
                        .confirmationDialog(
                            "Select trace type",
                            isPresented: $traceTypeSelectionIsOpen,
                            titleVisibility: .visible,
                            actions: { traceTypePickerButtons }
                        )
                        .confirmationDialog(
                            "Select terminal",
                            isPresented: $terminalSelectionIsOpen,
                            titleVisibility: .visible,
                            actions: { terminalPickerButtons }
                        )
                        .onChange(of: traceTypeSelectionIsOpen) { _ in
                            // If type selection is closed and a new trace wasn't initialized we can
                            // figure that the user opted to cancel.
                            if !traceTypeSelectionIsOpen && pendingTraceParameters == nil { reset() }
                        }
                        .onDisappear {
                            ArcGISEnvironment.authenticationManager.arcGISCredentialStore.removeAll()
                        }
                        .task {
                            await setup()
                        }
                        .task(id: lastSingleTap?.mapPoint) {
                            guard case .settingPoints = tracingActivity, let lastSingleTap else {
                                return
                            }
                            if let feature = await identifyFeatureAt(
                                lastSingleTap.screenPoint,
                                with: mapViewProxy
                            ) {
                                add(feature, at: lastSingleTap.mapPoint)
                            }
                        }
                        .task(id: tracingActivity) {
                            updateUserHint()
                            if tracingActivity == .tracing {
                                await trace()
                            }
                        }
                }
                traceManager
                    .frame(width: geometryProxy.size.width)
                    .background(.thinMaterial)
            }
        }
    }
    
    /// The view at the bottom of the screen that guides the user through the various stages of a
    /// tracing activity.
    var traceManager: some View {
        HStack(spacing: 5) {
            switch tracingActivity {
            case .none:
                Button("Start a New Trace") {
                    withAnimation {
                        tracingActivity = .settingType
                        traceTypeSelectionIsOpen.toggle()
                    }
                }
                .padding()
            case .settingPoints:
                controlsForSettingPoints
            case .settingType:
                EmptyView()
            case .tracing:
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .padding()
            case .viewingResults:
                Button("Reset", role: .destructive) {
                    reset()
                }
                .padding()
            }
        }
    }
}

private extension ArcGISCredential {
    /// The public credentials for the data in this sample.
    /// - Note: Never hardcode login information in a production application. This is done solely
    /// for the sake of the sample.
    static var publicSample: ArcGISCredential {
        get async throws {
            try await TokenCredential.credential(
                for: .samplePortal,
                username: "viewer01",
                password: "I68VGU^nMurF"
            )
        }
    }
}

private extension SimpleMarkerSymbol {
    /// The symbol for barrier elements.
    static var barrier: SimpleMarkerSymbol {
        .init(style: .x, color: .red, size: 20)
    }
    
    /// The symbol for starting location elements.
    static var startingLocation: SimpleMarkerSymbol {
        .init(style: .cross, color: .green, size: 20)
    }
}

extension TraceUtilityNetworkView {
    /// The buttons and picker shown to the user while setting points.
    @ViewBuilder
    private var controlsForSettingPoints: some View {
        Picker("Add starting points & barriers", selection: pointType) {
            ForEach([PointType.start, PointType.barrier], id: \.self) { type in
                Text(type.rawValue.capitalized).tag(type)
            }
        }
        .padding()
        .pickerStyle(.segmented)
        Button("Trace") {
            tracingActivity = .tracing
        }
        .disabled(pendingTraceParameters?.startingLocations.isEmpty ?? true)
        .padding()
        Button("Reset", role: .destructive) {
            reset()
        }
        .padding()
    }
    
    /// The domain network for this sample.
    private var electricDistribution: UtilityDomainNetwork? {
        network?.definition?.domainNetwork(named: "ElectricDistribution")
    }
    
    /// The URLs of the relevant feature layers for this sample.
    ///
    /// The feature layers allow us to modify the visual rendering style of different elements in
    /// the network.
    private var featureLayerURLs: [URL] {
        return [
            .featureService.appendingPathComponent("0"),
            .featureService.appendingPathComponent("3")
        ]
    }
    
    /// The utility tier for this sample.
    private var mediumVoltageRadial: UtilityTier? {
        electricDistribution?.tier(named: "Medium Voltage Radial")
    }
    
    /// The utility network for this sample.
    private var network: UtilityNetwork? {
        model.map.utilityNetworks.first
    }
    
    /// Determines whether the user is setting starting points or barriers.
    ///
    /// - Note: This should only be used when the user is setting starting points or barriers. If
    /// this condition isn't present, gets will be inaccurate and sets will be ignored.
    private var pointType: Binding<PointType> {
        .init(
            get: {
                guard case .settingPoints(let pointType) = tracingActivity else {
                    return .start
                }
                return pointType
            },
            set: {
                guard case .settingPoints = tracingActivity else { return }
                tracingActivity = .settingPoints(pointType: $0)
            }
        )
    }
    
    /// The trace types supported for this sample.
    private var supportedTraceTypes: [UtilityTraceParameters.TraceType] {
        return [.connected, .subnetwork, .upstream, .downstream]
    }
    
    /// Buttons for each the available terminals on the last added utility element.
    @ViewBuilder
    private var terminalPickerButtons: some View {
        ForEach(lastAddedElement?.assetType.terminalConfiguration?.terminals ?? []) { terminal in
            Button(terminal.name) {
                lastAddedElement?.terminal = terminal
                updateUserHint(withMessage: "terminal: \(terminal.name)")
            }
        }
    }
    
    /// Buttons for each the supported trace types.
    ///
    /// When a trace type is selected, the pending trace is initialized as a new instance of trace
    /// parameters. The trace configuration can also be set. The user should set trace points next.
    @ViewBuilder
    private var traceTypePickerButtons: some View {
        ForEach(supportedTraceTypes, id: \.self) { type in
            Button(type.displayName) {
                pendingTraceParameters = UtilityTraceParameters(traceType: type, startingLocations: [])
                pendingTraceParameters?.traceConfiguration = mediumVoltageRadial?.defaultTraceConfiguration
                tracingActivity = .settingPoints(pointType: .start)
            }
        }
    }
}

private extension UIColor {
    /// A custom color for electrical lines in the utility network.
    static var darkCyan: UIColor {
        .init(red: 0, green: 0.55, blue: 0.55, alpha: 1)
    }
}

private extension UniqueValue {
    /// The rendering style for low voltage lines in the utility network.
    static var lowVoltage: UniqueValue {
        .init(
            label: "Low voltage",
            symbol: SimpleLineSymbol(style: .dash, color: .darkCyan, width: 3),
            values: [3]
        )
    }
    
    /// The rendering style for medium voltage lines in the utility network.
    static var mediumVoltage: UniqueValue {
        .init(
            label: "Medium voltage",
            symbol: SimpleLineSymbol(style: .solid, color: .darkCyan, width: 3),
            values: [5]
        )
    }
}

private extension URL {
    /// The server containing the data for this sample.
    static var sampleServer7: URL {
        URL(string: "https://sampleserver7.arcgisonline.com")!
    }
    
    /// The feature service containing the data for this sample.
    static var featureService: URL {
        sampleServer7.appendingPathComponent("server/rest/services/UtilityNetwork/NapervilleElectric/FeatureServer")
    }
    
    /// The portal containing the data for this sample.
    static var samplePortal: URL {
        sampleServer7.appendingPathComponent("portal/sharing/rest")
    }
}

private extension UtilityTraceParameters.TraceType {
    /// The name of this trace type, capitalized.
    var displayName: String {
        String(describing: self).capitalized
    }
}

private extension Viewpoint {
    /// The initial viewpoint to be displayed when the sample is first opened.
    static var initialViewpoint: Viewpoint {
        .init(
            boundingGeometry: Envelope(
                xRange: (-9813547.35557238)...(-9813185.0602376),
                yRange: (5129980.36635111)...(5130215.41254146)
            )
        )
    }
}
