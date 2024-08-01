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

struct EditFeaturesWithFeatureLinkedAnnotationView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// The asynchronous action currently being preformed.
    @State private var selectedAction = AsyncAction.setUpMap
    
    /// The current instruction being displayed at the top of the screen.
    @State private var instruction = Instruction.selectFeature
    
    /// The point on the map where the user tapped.
    @State private var tapLocation: Point?
    
    /// The building number of the selected feature.
    @State private var buildingNumber: Int32?
    
    /// The street name of the selected feature.
    @State private var streetName: String = ""
    
    /// A Boolean value indicating whether the edit address alert is presented.
    @State private var editAddressAlertIsPresented = false
    
    /// A Boolean value indicating whether the move confirmation alert is presented.
    @State private var moveConfirmationAlertIsPresented = false
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    var body: some View {
        MapViewReader { mapViewProxy in
            MapView(map: model.map)
                .onSingleTapGesture { screenPoint, mapPoint in
                    if model.selectedFeature == nil {
                        // Selects a feature at the tap location if there isn't one selected.
                        selectedAction = .selectFeature(screenPoint: screenPoint)
                    } else {
                        // Shows the move confirmation alert if there is already a selected feature.
                        tapLocation = mapPoint
                        moveConfirmationAlertIsPresented = true
                    }
                }
                .task(id: selectedAction) {
                    do {
                        // Performs the selected action.
                        switch selectedAction {
                        case .setUpMap:
                            try await model.setUpMap()
                        case .selectFeature(let screenPoint):
                            let layerIdentifyResults = try await mapViewProxy.identifyLayers(
                                screenPoint: screenPoint,
                                tolerance: 10
                            )
                            model.selectFirstFeature(from: layerIdentifyResults)
                            
                            if model.selectedFeature != nil {
                                instruction = .moveFeature
                            }
                        case .setFeatureAddress(let buildingNumber, let streetName):
                            try await model.setFeatureAddress(
                                buildingNumber: buildingNumber,
                                streetName: streetName
                            )
                            instruction = .moveFeature
                        case .updateFeatureGeometry(let mapPoint):
                            try await model.updateFeatureGeometry(with: mapPoint)
                            instruction = .selectFeature
                        }
                    } catch {
                        self.error = error
                    }
                }
                .errorAlert(presentingError: $error)
                .overlay(alignment: .top) {
                    Text(instruction.message)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(8)
                        .background(.regularMaterial, ignoresSafeAreaEdges: .horizontal)
                }
        }
        .onChange(of: model.selectedFeature == nil) { _ in
            if model.selectedFeature?.geometry is Point,
               let featureAddress = model.selectedFeatureAddress {
                // Presents the alert to update the feature's address if the feature is a point.
                buildingNumber = featureAddress.buildingNumber
                streetName = featureAddress.streetName
                editAddressAlertIsPresented = true
            } else if let polyline = model.selectedFeature?.geometry as? Polyline,
                      polyline.parts.contains(where: { $0.points.count > 2 }) {
                // Shows a message if the feature is a polyline with any part
                // containing more than one segment, i.e., a curve.
                instruction = .selectStraightPolyline
                model.clearSelectedFeature()
            }
        }
        .alert("Edit Address", isPresented: $editAddressAlertIsPresented) {
            TextField("Building Number", value: $buildingNumber, format: .number.grouping(.never))
                .keyboardType(.numberPad)
            TextField("Street Name", text: $streetName)
            Button("Cancel", role: .cancel) {
                model.clearSelectedFeature()
                instruction = .selectFeature
            }
            Button("Done") {
                selectedAction = .setFeatureAddress(
                    buildingNumber: buildingNumber!,
                    streetName: streetName
                )
            }
            .disabled(buildingNumber == nil || streetName.isEmpty)
        } message: {
            Text("Edit the feature's 'AD_ADDRESS' and 'ST_STR_NAM' attributes.")
        }
        .alert("Confirm Move", isPresented: $moveConfirmationAlertIsPresented) {
            Button("Cancel", role: .cancel) {
                model.clearSelectedFeature()
                instruction = .selectFeature
            }
            Button("Move") {
                selectedAction = .updateFeatureGeometry(mapPoint: tapLocation!)
            }
        } message: {
            Text("Are you sure you want to move the selected feature?")
        }
    }
}

private extension EditFeaturesWithFeatureLinkedAnnotationView {
    /// An asynchronous action associated with the sample.
    enum AsyncAction: Equatable {
        /// Sets up the map for the sample.
        case setUpMap
        /// Selects a feature identified at a given point on the screen.
        case selectFeature(screenPoint: CGPoint)
        /// Sets the address attributes of the selected feature to given values.
        case setFeatureAddress(buildingNumber: Int32, streetName: String)
        /// Updates the selected feature's geometry using a given point on the map.
        case updateFeatureGeometry(mapPoint: Point)
    }
    
    /// An instruction associated with the sample.
    enum Instruction {
        case selectFeature, selectStraightPolyline, moveFeature
        
        /// The message for the instruction.
        var message: String {
            switch self {
            case .selectFeature: "Select a point or polyline to edit."
            case .selectStraightPolyline: "Select straight (single segment) polylines only."
            case .moveFeature: "Tap on the map to move the feature."
            }
        }
    }
}
