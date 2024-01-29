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

struct AddFeaturesWithContingentValuesView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// The point on the map where the user tapped.
    @State private var tapLocation: Point?
    
    /// A Boolean value indicating whether the add feature sheet is presented.
    @State private var addFeatureSheetIsPresented = false
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    var body: some View {
        ZStack {
            GeometryReader { geometryProxy in
                MapViewReader { mapViewProxy in
                    MapView(map: model.map, graphicsOverlays: [model.graphicsOverlay])
                        .onSingleTapGesture { _, mapPoint in
                            tapLocation = mapPoint
                        }
                        .task(id: tapLocation) {
                            // Add a feature representing a bird's nest when the map is tapped.
                            guard let tapLocation else { return }
                            
                            do {
                                try await model.addFeature(at: tapLocation)
                                addFeatureSheetIsPresented = true
                                
                                // Create an envelope from the screen's frame.
                                let viewRect = geometryProxy.frame(in: .local)
                                guard let viewExtent = mapViewProxy.envelope(
                                    fromViewRect: viewRect
                                ) else { return }
                                
                                // Update the map's viewpoint with an offsetted tap location
                                // to center the feature in the top half of the screen.
                                let yOffset = (viewExtent.height / 2) / 2
                                let newViewpointCenter = Point(
                                    x: tapLocation.x,
                                    y: tapLocation.y - yOffset
                                )
                                await mapViewProxy.setViewpointCenter(newViewpointCenter)
                            } catch {
                                self.error = error
                            }
                        }
                        .task {
                            do {
                                // Load the features from the geodatabase when the sample loads.
                                try await model.loadFeatures()
                                
                                // Zoom to the extent of the added layer.
                                guard let extent = model.map.operationalLayers.first?.fullExtent
                                else { return }
                                await mapViewProxy.setViewpointGeometry(extent, padding: 15)
                            } catch {
                                self.error = error
                            }
                        }
                }
            }
            
            VStack {
                Spacer()
                
                // A button that allows the popover to display.
                Button("") {}
                    .opacity(0)
                    .sheet(isPresented: $addFeatureSheetIsPresented, detents: [.medium]) {
                        NavigationView {
                            AddFeatureView(model: model)
                                .navigationTitle("Add Bird Nest")
                                .navigationBarTitleDisplayMode(.inline)
                                .toolbar {
                                    ToolbarItem(placement: .cancellationAction) {
                                        Button("Cancel", role: .cancel) {
                                            addFeatureSheetIsPresented = false
                                        }
                                    }
                                    
                                    ToolbarItem(placement: .confirmationAction) {
                                        Button("Done") {
                                            addFeatureSheetIsPresented = false
                                        }
                                        .disabled(!model.contingenciesAreValid)
                                    }
                                }
                        }
                        .navigationViewStyle(.stack)
                    }
                    .task(id: addFeatureSheetIsPresented) {
                        // When the sheet closes, remove the feature if it is invalid.
                        guard !addFeatureSheetIsPresented,
                              !model.contingenciesAreValid,
                              model.feature != nil
                        else { return }
                        
                        do {
                            try await model.removeFeature()
                        } catch {
                            self.error = error
                        }
                    }
            }
        }
        .errorAlert(presentingError: $error)
    }
}
