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

struct RunValveIsolationTraceView: View {
    /// The view model for the sample.
    @StateObject var model = Model()
    
    /// The last locations in the screen and map where a tap occurred.
    @State var lastSingleTap: (screenPoint: CGPoint, mapPoint: Point)?
    
    /// A Boolean value indicating if the configuration sheet is presented.
    @State var isConfigurationPresented = false
    
    var body: some View {
        MapViewReader { mapViewProxy in
            MapView(
                map: model.map,
                graphicsOverlays: [model.parametersOverlay]
            )
            .onSingleTapGesture { screenPoint, mapPoint in
                lastSingleTap = (screenPoint, mapPoint)
            }
            .overlay(alignment: .top) {
                Text(model.statusText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(8)
                    .background(.ultraThinMaterial, ignoresSafeAreaEdges: .horizontal)
                    .multilineTextAlignment(.center)
            }
            .task {
                do {
                    try await model.setup()
                } catch {
                    model.statusText = error.localizedDescription
                }
                await mapViewProxy.setViewpointCenter(model.startingLocationPoint, scale: 3_000)
            }
            .task(id: lastSingleTap?.mapPoint) {
                guard let lastSingleTap = lastSingleTap else {
                    return
                }
                if let feature = try? await mapViewProxy.identifyLayers(
                    screenPoint: lastSingleTap.screenPoint,
                    tolerance: 10
                ).first?.geoElements.first as? ArcGISFeature {
                    model.addFilterBarrier(for: feature, at: lastSingleTap.mapPoint)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button {
                        isConfigurationPresented.toggle()
                    } label: {
                        Text("Configuration")
                    }
                    .disabled(model.traceCompleted)
                    Spacer()
                    Button("Trace") {
                        Task { try await model.trace() }
                    }
                    .disabled(!model.traceEnabled)
                    Spacer()
                    Button("Reset") {
                        model.reset()
                        Task { await mapViewProxy.setViewpointCenter(model.startingLocationPoint, scale: 3_000) }
                    }
                    .disabled(!model.resetEnabled)
                }
            }
            .sheet(isPresented: $isConfigurationPresented) {
                Form {
                    Section {
                        List(model.filterBarrierCategories, id: \.self, selection: $model.selectedCategory) { category in
                            HStack {
                                Text(category.name)
                                Spacer()
                                if category == model.selectedCategory {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                            // Allows the whole row to be tapped. Without this only the text is
                            // tappable.
                            .contentShape(Rectangle())
                            .onTapGesture {
                                model.selectCategory(category)
                            }
                        }
                        .disabled(model.traceCompleted)
                    } header: {
                        Text("Category")
                    } footer: {
                        Text("Choose a category to run the valve isolation trace. The selected utility category defines constraints and conditions based upon specific characteristics of asset types in the utility network")
                    }
                    Section {
                        Toggle(isOn: $model.includesIsolatedFeatures) {
                            Text("Include Isolated Features")
                        }
                    } header: {
                        Text("Other Options")
                    } footer: {
                        Text("Choose whether or not the trace should include isolated features. This means that isolated features are included in the trace results when used in conjunction with an isolation trace.")
                    }
                    .toggleStyle(.switch)
                    .disabled(model.traceCompleted)
                }
            }
            .overlay(alignment: .center) {
                if model.tracingActivity != .none {
                    VStack {
                        Text(model.tracingActivity.label)
                        ProgressView()
                            .progressViewStyle(.circular)
                    }
                    .padding(6)
                    .background(.thinMaterial)
                    .cornerRadius(10)
                }
            }
            .alert(
                "Select terminal",
                isPresented: $model.terminalSelectorIsOpen,
                actions: { terminalPickerButtons }
            )
        }
    }
    
    /// Buttons for each the available terminals on the last added utility element.
    @ViewBuilder var terminalPickerButtons: some View {
        ForEach(model.lastAddedElement?.assetType.terminalConfiguration?.terminals ?? []) { terminal in
            Button(terminal.name) {
                model.lastAddedElement?.terminal = terminal
                model.terminalSelectorIsOpen = false
                model.addTerminal(to: lastSingleTap!.mapPoint)
            }
        }
    }
}
