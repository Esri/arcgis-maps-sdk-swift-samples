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
    
    /// The feature type to be added or removed from the map.
    @State private var featureSelection: AddableFeature = .stop
    
    /// A Boolean value indicating whether a routing operation is in progress.
    @State private var routing = false
    
    /// A Boolean value indicating whether routing will find the best sequence.
    @State private var findsBestSequence = false
    
    /// A Boolean value indicating whether the error alert is showing.
    @State private var errorAlertIsShowing = false
    
    /// The error shown in the error alert.
    @State private var error: Error? {
        didSet { errorAlertIsShowing = error != nil }
    }
    
    var body: some View {
        MapViewReader { mapViewProxy in
            MapView(map: model.map, graphicsOverlays: model.graphicsOverlays)
                .onSingleTapGesture { _, mapPoint in
                    // Normalize the map point.
                    guard let normalizedPoint = GeometryEngine.normalizeCentralMeridian(
                        of: mapPoint
                    ) as? Point else { return }
                    
                    // Add a stop or barrier depending on the current feature selection.
                    if featureSelection == .stop {
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
                    if routing {
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
                            Task {
                                do {
                                    routing = true
                                    defer { routing = false }
                                    try await model.route()
                                    
                                    // Update the viewpoint to the new route.
                                    guard let geometry = model.route?.geometry else { return }
                                    await mapViewProxy.setViewpointGeometry(geometry, padding: 50)
                                } catch {
                                    self.error = error
                                }
                            }
                        }
                        .disabled(model.stopsCount < 2)
                        Spacer()
                        
                        SheetButton(title: "Directions") {
                            List {
                                ForEach(
                                    Array((model.route?.directionManeuvers ?? []).enumerated()),
                                    id: \.offset
                                ) { (_, direction) in
                                    Button {
                                        Task {
                                            guard let geometry = direction.geometry else { return }
                                            model.directionGraphic.geometry = geometry
                                            await mapViewProxy.setViewpointGeometry(
                                                geometry,
                                                padding: 100
                                            )
                                        }
                                    } label: {
                                        Text(direction.text)
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.triangle.turn.up.right.diamond")
                        }
                        .disabled(model.route == nil)
                        Spacer()
                        
                        Picker("Feature Type", selection: $featureSelection) {
                            Text("Stops").tag(AddableFeature.stop)
                            Text("Barriers").tag(AddableFeature.barrier)
                        }
                        .pickerStyle(.segmented)
                        Spacer()
                        
                        SheetButton(title: "Settings") {
                            List {
                                Toggle(isOn: $findsBestSequence) {
                                    Text("Find Best Sequence")
                                }
                                .onChange(of: findsBestSequence) { newValue in
                                    model.routeParameters.findsBestSequence = newValue
                                }
                                
                                Section {
                                    Toggle(isOn: Binding(
                                        get: { model.routeParameters.preservesFirstStop },
                                        set: { model.routeParameters.preservesFirstStop = $0 }
                                    )) {
                                        Text("Preserve First Stop")
                                    }
                                    
                                    Toggle(isOn: Binding(
                                        get: { model.routeParameters.preservesLastStop },
                                        set: { model.routeParameters.preservesLastStop = $0 }
                                    )) {
                                        Text("Preserve Last Stop")
                                    }
                                }
                                .disabled(!findsBestSequence)
                            }
                        } label: {
                            Image(systemName: "gear")
                        }
                        Spacer()
                        
                        Button {
                            model.reset(featureType: featureSelection)
                        } label: {
                            Image(systemName: "trash")
                        }
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
        .alert(isPresented: $errorAlertIsShowing, presentingError: error)
    }
}

private extension FindRouteAroundBarriersView {
    /// A button with a given label that brings up a sheet containing given content.
    struct SheetButton<Content: View, Label: View>: View {
        /// The string to display as the title of the sheet
        let title: String
        
        /// A view that contains the content to display in the sheet.
        @ViewBuilder let content: () -> Content
        
        /// A view that describes the purpose of the button.
        @ViewBuilder let label: () -> Label
        
        /// A Boolean value indicating whether the sheet is showing.
        @State private var sheetIsShowing = false
        
        var body: some View {
            if #available(iOS 16, *) {
                button
                    .popover(isPresented: $sheetIsShowing, arrowEdge: .bottom) {
                        sheetContent
                            .presentationDetents([.fraction(0.5)])
#if targetEnvironment(macCatalyst)
                            .frame(minWidth: 300, minHeight: 270)
#else
                            .frame(minWidth: 320, minHeight: 390)
#endif
                    }
            } else {
                button
                    .sheet(isPresented: $sheetIsShowing, detents: [.medium]) {
                        sheetContent
                    }
            }
        }
        
        /// The button that presents the sheet.
        @ViewBuilder private var button: some View {
            Button {
                sheetIsShowing = true
            } label: {
                label()
            }
        }
        
        /// The content to display in the sheet with a title and done button.
        @ViewBuilder private var sheetContent: some View {
            NavigationView {
                content()
                    .navigationTitle(title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                sheetIsShowing = false
                            }
                        }
                    }
            }
            .navigationViewStyle(.stack)
            .frame(idealWidth: 320, idealHeight: 428)
        }
    }
}
