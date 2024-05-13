// Copyright 2024 Esri
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

struct EditWithBranchVersioningView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// The placement of the callout for the selected feature.
    @State private var calloutPlacement: CalloutPlacement?
    
    /// The parameters used to create a new version.
    @State private var versionParameters: ServiceVersionParameters?
    
    /// The text representing the status of the sample.
    @State private var statusText = ""
    
    /// The asynchronous action currently being preformed.
    @State private var selectedAction: AsyncAction? = .setUp
    
    /// The point on the map to move the selected feature to.
    @State private var moveLocation: Point?
    
    /// A Boolean value indicating whether the move confirmation alert is presented.
    @State private var isMovingFeature = false
    
    /// A Boolean value indicating whether the create version parameters popover is presented.
    @State private var isCreatingVersion = false
    
    /// A Boolean value indicating whether the switch version dialog is presented.
    @State private var isSwitchingVersion = false
    
    /// A Boolean value indicating whether the set damage type dialog is presented.
    @State private var isSettingDamageType = false
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    var body: some View {
        MapViewReader { mapViewProxy in
            MapView(map: model.map)
                .callout(placement: $calloutPlacement.animation(.default.speed(2))) { placement in
                    let placeName = placement.geoElement?.attributes[.placeNameKey] as? String
                    let damageType = placement.geoElement?.attributes[.damageTypeKey] as? String
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text(placeName ?? "")
                                .font(.headline)
                            Text(damageType ?? "")
                                .font(.callout)
                        }
                        editDamageTypeButton
                    }
                    .padding(5)
                }
                .onSingleTapGesture { screenPoint, mapPoint in
                    if model.selectedFeature != nil && !model.onDefaultVersion {
                        // Shows the move confirmation alert if there is already a feature selected.
                        isMovingFeature = true
                        moveLocation = mapPoint
                    } else {
                        // Identifies and selects the feature at the tap location.
                        selectedAction = .selectFeature(screenPoint: screenPoint, mapPoint: mapPoint)
                    }
                }
                .alert(
                    "Confirm Move",
                    isPresented: $isMovingFeature,
                    presenting: moveLocation,
                    actions: { mapPoint in
                        Button("Cancel", role: .cancel) {
                            calloutPlacement = nil
                            model.clearSelection()
                        }
                        Button("Move") {
                            model.selectedFeature?.geometry = mapPoint
                            selectedAction = .updateFeature
                        }
                    },
                    message: { _ in
                        Text("Do you want to move the selected feature?")
                    }
                )
                .task(id: selectedAction) {
                    guard let selectedAction else { return }
                    calloutPlacement = nil
                    
                    do {
                        switch selectedAction {
                        case .setUp:
                            statusText = "Loading service geodatabase…"
                            try await model.setUp()
                            
                            guard let versionName = model.existingVersionNames.first else { break }
                            statusText = "Version: \(versionName)"
                        case .makeVersion:
                            let name = try await model.createVersion(parameters: versionParameters!)
                            statusText = "Created: \(name)"
                        case .switchToVersion(let version):
                            try await model.switchToVersion(named: version)
                            statusText = "Version: \(version)"
                        case .updateFeature:
                            try await model.updateFeature()
                        case .selectFeature(let screenPoint, let mapPoint):
                            model.clearSelection()
                            
                            // Identifies the feature on the feature layer at the tapped point.
                            let result = try await mapViewProxy.identify(
                                on: model.featureLayer,
                                screenPoint: screenPoint,
                                tolerance: 10
                            )
                            
                            if let feature = result.geoElements.first as? Feature {
                                model.selectFeature(feature)
                                calloutPlacement = .geoElement(feature, tapLocation: mapPoint)
                            }
                        }
                    } catch {
                        self.error = error
                    }
                    
                    // Resets the selected action so an action of the same type can be run again.
                    self.selectedAction = nil
                }
        }
        .overlay(alignment: .top) {
            Text(statusText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(8)
                .background(.regularMaterial, ignoresSafeAreaEdges: .horizontal)
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                createVersionButton
                switchVersionButton
            }
        }
        .errorAlert(presentingError: $error)
    }
    
    /// The button for editing the damage type of the selected feature.
    private var editDamageTypeButton: some View {
        Button("Edit", systemImage: "pencil") {
            isSettingDamageType = true
        }
        .imageScale(.large)
        .labelStyle(.iconOnly)
        .disabled(model.onDefaultVersion)
        .confirmationDialog("Damage Type", isPresented: $isSettingDamageType, titleVisibility: .visible) {
            ForEach(DamageType.allCases, id: \.self) { damageType in
                Button(damageType.label) {
                    model.selectedFeature?.setAttributeValue(
                        damageType.rawValue,
                        forKey: .damageTypeKey
                    )
                    selectedAction = .updateFeature
                }
            }
        } message: {
            Text("Choose a damage type for the building.")
        }
    }
    
    /// The button for creating a version.
    private var createVersionButton: some View {
        Button("Create") {
            isCreatingVersion = true
        }
        .popover(isPresented: $isCreatingVersion) {
            CreateVersionParametersView(model: model) { parameters in
                // Makes a new version with the created parameters.
                versionParameters = parameters
                selectedAction = .makeVersion
            }
            .presentationDetents([.fraction(0.5)])
            .frame(idealWidth: 320, idealHeight: 200)
        }
    }
    
    /// The button for switching the current version.
    private var switchVersionButton: some View {
        Button("Switch") {
            isSwitchingVersion = true
        }
        .disabled(model.existingVersionNames.count < 2)
        .confirmationDialog("Versions", isPresented: $isSwitchingVersion, titleVisibility: .visible) {
            ForEach(model.existingVersionNames, id: \.self) { versionName in
                Button(versionName) {
                    selectedAction = .switchToVersion(version: versionName)
                }
            }
        } message: {
            Text("Choose a version to switch to.")
        }
    }
}

/// An asynchronous action associated with the sample.
private enum AsyncAction: Equatable {
    /// Sets up the sample.
    case setUp
    /// Makes a version with the current version parameters.
    case makeVersion
    /// Switches to a version with an associated version name.
    case switchToVersion(version: String)
    /// Select a feature identified from an associated screen and map point.
    case selectFeature(screenPoint: CGPoint, mapPoint: Point)
    /// Updates the selected feature in it's feature table.
    case updateFeature
}

/// The damage type of a feature.
private enum DamageType: String, CaseIterable {
    case destroyed, major, minor, affected, inaccessible, `default`
    
    /// A human-readable label for the damage type.
    var label: String {
        switch self {
        case .destroyed: "Destroyed"
        case .major: "Major"
        case .minor: "Minor"
        case .affected: "Affected"
        case .inaccessible: "Inaccessible"
        case .default: "Default"
        }
    }
}

private extension String {
    /// The key for a feature's damage type attribute.
    static let damageTypeKey = "typdamage"
    /// The key for a feature's place name attribute.
    static let placeNameKey = "placename"
}

#Preview {
    NavigationStack {
        EditWithBranchVersioningView()
    }
}
