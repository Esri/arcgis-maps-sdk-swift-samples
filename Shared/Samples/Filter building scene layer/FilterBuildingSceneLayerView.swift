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
import ArcGISToolkit
import SwiftUI

struct FilterBuildingSceneLayerView: View {
    /// A scene with the building scene layer which displays ESRI building E.
    @State private var scene = Scene(url: URL(string: "https://www.arcgis.com/home/item.html?id=b7c387d599a84a50aafaece5ca139d44")!)!
    /// The building scene layer used in the scene.
    ///
    /// This is used to set the active filter on the layer.
    @State private var buildingSceneLayer: BuildingSceneLayer?
    /// A Boolean value indicating if the settings are visible or not.
    @State private var settingsAreVisible = false
    /// The available floors to show in the settings.
    @State private var availableFloors: [String] = []
    /// The selected floor from the floor picker in the settings.
    @State private var selectedFloor: String = .allFloorsLabel
    /// The group sublayers used to build the visibility toggles in the settings.
    @State private var groupSublayers: [BuildingGroupSublayer] = []
    /// The error shown in the error alert.
    @State private var error: (any Error)?
    /// The point where the user has tapped on the screen.
    @State private var tapPoint: CGPoint?
    /// The building sublayer that has a feature selected.
    ///
    /// This is used to clear the feature selection.
    @State private var selectedSublayer: BuildingComponentSublayer?
    /// The popup to be shown as the result of the layer identify operation.
    @State private var popup: Popup? {
        didSet { showPopup = popup != nil }
    }
    /// A Boolean value specifying whether the popup view should be shown or not.
    @State private var showPopup = false
    
    var body: some View {
        LocalSceneViewReader { proxy in
            LocalSceneView(scene: scene)
                .onSingleTapGesture { screenPoint, _ in
                    tapPoint = screenPoint
                }
                .task {
                    do {
                        try await scene.load()
                        
                        guard let buildingSceneLayer = scene.operationalLayers.first as? BuildingSceneLayer else { return }
                        
                        try await buildingSceneLayer.load()
                        self.buildingSceneLayer = buildingSceneLayer
                        
                        // Gets the full model which contains all the sublayers.
                        guard let fullModelSublayer = buildingSceneLayer.sublayers
                            .first(where: { $0.name == "Full Model" }) as? BuildingGroupSublayer else { return }
                        
                        groupSublayers = fullModelSublayer.sublayers
                            .compactMap { $0 as? BuildingGroupSublayer }
                        
                        // Gets the attribute statistics to get the floor
                        // information.
                        let statistics = try await buildingSceneLayer.statistics
                        
                        // Gets the floor statistics.
                        guard let floorStatistics = statistics[.floorFieldKey] else { return }
                        
                        // Gets all the available floors and sorts the floors
                        // from top to bottom floor.
                        availableFloors = floorStatistics.mostFrequentValues.sorted { $0 > $1 } + [.allFloorsLabel]
                    } catch {
                        self.error = error
                    }
                }
                .task(id: tapPoint) {
                    // Clears any previous selection if there was a new
                    // tap on the screen.
                    selectedSublayer?.clearSelection()
                    
                    guard let tapPoint, let buildingSceneLayer else { return }
                    
                    let result = try? await proxy
                        .identify(on: buildingSceneLayer, screenPoint: tapPoint, tolerance: 5)
                    
                    let sublayerResult = result?.sublayerResults
                        // Get the first sublayer result that has geo elements.
                        .first(where: { !$0.geoElements.isEmpty })
                    
                    guard let sublayerResult,
                          let feature = sublayerResult.geoElements.first as? Feature,
                          let component = sublayerResult.layerContent as? BuildingComponentSublayer
                    else { return }
                    
                    component.selectFeature(feature)
                    popup = sublayerResult.popups.first
                    selectedSublayer = component
                }
        }
        .errorAlert(presentingError: $error)
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button("Settings", systemImage: "gear") {
                    settingsAreVisible = true
                }
                .popover(isPresented: $settingsAreVisible) { [settings] in
                    settings
                        .frame(idealWidth: 400, idealHeight: 500)
                        .presentationCompactAdaptation(.popover)
                }
            }
        }
        .popover(isPresented: $showPopup, attachmentAnchor: .point(.top)) { [popup] in
            PopupView(root: popup!, isPresented: $showPopup)
                .frame(idealWidth: 320, idealHeight: 600)
        }
    }
    
    /// The floor filter used with the building scene layer to show only the
    /// selected floor from the floor picker in the settings.
    private var floorFilter: BuildingFilter? {
        // To see all the floors we need to remove the filter
        // by setting it to 'nil'.
        guard selectedFloor != "All" else { return nil }
        
        return BuildingFilter(
            name: "Floor filter",
            description: "Show selected floor using filter blocks.",
            blocks: [
                BuildingFilterBlock(
                    title: "Solid",
                    whereClause: "\(String.floorFieldKey) = \(selectedFloor)",
                    mode: .solid()
                ),
                BuildingFilterBlock(
                    title: "Xray",
                    whereClause: "\(String.floorFieldKey) < \(selectedFloor)",
                    mode: .xray()
                )
            ]
        )
    }

    /// The settings used to filter the sublayer by floors and sublayers.
    private var settings: some View {
        NavigationStack {
            Form {
                Section("Floors") {
                    Picker("Floor", selection: $selectedFloor) {
                        ForEach(availableFloors, id: \.self) { floor in
                            Text(floor)
                        }
                    }
                    .onChange(of: selectedFloor) {
                        // If the selected floor changed then we need
                        // to update the active filter to show
                        // the selected floor.
                        buildingSceneLayer?.activeFilter = floorFilter
                    }
                }
                Section("Disciplines & Categories") {
                    ForEach(groupSublayers) { sublayer in
                        BuildingGroupSublayerToggleView(groupSublayer: sublayer)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        settingsAreVisible = false
                    }
                }
            }
        }
    }
}

private extension String {
    /// The attribute name for the floors.
    static var floorFieldKey: String { "BldgLevel" }
    /// The label used in the floor picker to see all the floors.
    static var allFloorsLabel: String { "All" }
}

#Preview {
    FilterBuildingSceneLayerView()
}
