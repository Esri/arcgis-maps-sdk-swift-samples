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

struct FindRouteAroundBarriersView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// The route features to be added or removed from the map.
    @State private var featuresSelection: RouteFeatures = .stops
    
    /// A Boolean value indicating whether a routing operation is in progress.
    @State private var routingIsInProgress = false
    
    /// The geometry of a direction maneuver to set the viewpoint to.
    @State private var directionGeometry: Geometry?
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    var body: some View {
        MapViewReader { mapViewProxy in
            MapView(map: model.map, graphicsOverlays: model.graphicsOverlays)
                .onSingleTapGesture { _, mapPoint in
                    // Normalize the map point.
                    guard let normalizedPoint = GeometryEngine.normalizeCentralMeridian(
                        of: mapPoint
                    ) as? Point else { return }
                    
                    // Add a stop or barrier depending on the current features selection.
                    if featuresSelection == .stops {
                        model.addStopGraphic(at: normalizedPoint)
                    } else {
                        model.addBarrierGraphic(at: normalizedPoint)
                    }
                }
                .overlay(alignment: .top) {
                    Text(model.routeInfoText)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(8)
                        .background(.thinMaterial, ignoresSafeAreaEdges: .horizontal)
                }
                .overlay(alignment: .center) {
                    if routingIsInProgress {
                        ProgressView("Routing...")
                            .padding()
                            .background(.ultraThickMaterial)
                            .cornerRadius(10)
                            .shadow(radius: 50)
                    }
                }
                .toolbar {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button("Route") {
                            routingIsInProgress = true
                        }
                        .disabled(model.stopsCount < 2)
                        .task(id: routingIsInProgress) {
                            guard routingIsInProgress else { return }
                            
                            do {
                                // Route when the button is pressed
                                try await model.route()
                                
                                // Update the viewpoint to the geometry of the new route.
                                guard let geometry = model.route?.geometry else { return }
                                await mapViewProxy.setViewpointGeometry(geometry, padding: 50)
                            } catch {
                                self.error = error
                            }
                            
                            routingIsInProgress = false
                        }
                        Spacer()
                        
                        SheetButton(title: "Directions") {
                            List {
                                ForEach(
                                    Array((model.route?.directionManeuvers ?? []).enumerated()),
                                    id: \.offset
                                ) { (_, direction) in
                                    Button {
                                        directionGeometry = direction.geometry
                                    } label: {
                                        Text(direction.text)
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.triangle.turn.up.right.diamond")
                        }
                        .disabled(model.route == nil)
                        .task(id: directionGeometry) {
                            guard let directionGeometry else { return }
                            model.directionGraphic.geometry = directionGeometry
                            await mapViewProxy.setViewpointGeometry(directionGeometry, padding: 100)
                        }
                        Spacer()
                        
                        Picker("Features", selection: $featuresSelection) {
                            Text("Stops").tag(RouteFeatures.stops)
                            Text("Barriers").tag(RouteFeatures.barriers)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        Spacer()
                        
                        SheetButton(title: "Route Settings") {
                            RouteParametersSettings(for: model.routeParameters)
                        } label: {
                            Image(systemName: "gear")
                        }
                        Spacer()
                        
                        Button {
                            model.reset(features: featuresSelection)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .disabled(
                            featuresSelection == .stops ? model.stopsCount == 0 :
                                model.barriersCount == 0
                        )
                    }
                }
        }
        .task {
            // Load the default route parameters from the route task when the sample loads.
            do {
                model.routeParameters = try await model.routeTask.makeDefaultParameters()
                model.routeParameters.returnsDirections = true
            } catch {
                self.error = error
            }
        }
        .errorAlert(presentingError: $error)
    }
}

#Preview {
    NavigationView {
        FindRouteAroundBarriersView()
    }
}
