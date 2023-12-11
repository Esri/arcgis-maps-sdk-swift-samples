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
    @StateObject private var model = Model()
    
    /// The last locations in the screen and map where a tap occurred.
    @State private var lastSingleTap: (screenPoint: CGPoint, mapPoint: Point)?
    
    /// A Boolean value indicating if the configuration sheet is presented.
    @State private var isConfigurationPresented = false
    
    /// A Boolean value indicating whether to include isolated features in the
    /// trace results when used in conjunction with an isolation trace.
    @State private var includeIsolatedFeatures = true
    
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
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(.ultraThinMaterial, ignoresSafeAreaEdges: .horizontal)
                    .multilineTextAlignment(.center)
            }
            .task {
                await model.setup()
                if let point = model.startingLocationPoint {
                    await mapViewProxy.setViewpointCenter(point, scale: 3_000)
                }
            }
            .task(id: lastSingleTap?.mapPoint) {
                guard let lastSingleTap else {
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
                    Button("Configuration") {
                        isConfigurationPresented.toggle()
                    }
                    .disabled(model.tracingActivity == .runningTrace ||
                              model.tracingActivity == .loadingServiceGeodatabase ||
                              model.tracingActivity == .loadingNetwork)
                    Spacer()
                    Button("Trace") {
                        Task { await model.trace(includeIsolatedFeatures: includeIsolatedFeatures) }
                    }
                    .disabled(!model.traceEnabled)
                    Spacer()
                    Button("Reset") {
                        model.reset()
                        if let point = model.startingLocationPoint {
                            Task { await mapViewProxy.setViewpointCenter(point, scale: 3_000) }
                        }
                    }
                    .disabled(!model.resetEnabled)
                }
            }
            .sheet(isPresented: $isConfigurationPresented) {
                if #available(iOS 16, *) {
                    NavigationStack {
                        configurationView
                    }
                } else {
                    NavigationView {
                        configurationView
                    }
                }
            }
            .overlay(alignment: .center) {
                if let tracingActivity = model.tracingActivity {
                    VStack {
                        Text(tracingActivity.label)
                        ProgressView()
                            .progressViewStyle(.circular)
                    }
                    .padding()
                    .background(.thinMaterial)
                    .cornerRadius(10)
                }
            }
            .alert(
                "Select Terminal",
                isPresented: $model.terminalSelectorIsOpen,
                actions: { terminalPickerButtons }
            )
        }
    }
    
    /// Buttons for each the available terminals on the last added utility element.
    @ViewBuilder var terminalPickerButtons: some View {
        if let lastAddedElement = model.lastAddedElement,
           let terminalConfiguration = lastAddedElement.assetType.terminalConfiguration {
            ForEach(terminalConfiguration.terminals) { terminal in
                Button(terminal.name) {
                    lastAddedElement.terminal = terminal
                    model.terminalSelectorIsOpen = false
                    model.addTerminal(to: lastSingleTap!.mapPoint)
                }
            }
        }
    }
    
    @ViewBuilder var configurationView: some View {
        Form {
            Section {
                List(model.filterBarrierCategories, id: \.name) { category in
                    HStack {
                        Text(category.name)
                        Spacer()
                        if category === model.selectedCategory {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                    // Allows the whole row to be tapped. Without this only the text is
                    // tappable.
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if category.name == model.selectedCategory?.name {
                            model.unselectCategory(category)
                        } else {
                            model.selectCategory(category)
                        }
                    }
                }
            } header: {
                Text("Category")
            } footer: {
                Text("Choose a category to run the valve isolation trace. The selected utility category defines constraints and conditions based upon specific characteristics of asset types in the utility network.")
            }
            Section {
                Toggle(isOn: $includeIsolatedFeatures) {
                    Text("Include Isolated Features")
                }
            } header: {
                Text("Other Options")
            } footer: {
                Text("Choose whether or not the trace should include isolated features. This means that isolated features are included in the trace results when used in conjunction with an isolation trace.")
            }
            .toggleStyle(.switch)
        }
        .navigationTitle("Configuration")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { isConfigurationPresented = false }
            }
        }
        .navigationViewStyle(.stack)
    }
}

extension RunValveIsolationTraceView.Model.TracingActivity {
    /// A human-readable label for the tracing activity.
    var label: String {
        switch self {
        case .loadingServiceGeodatabase: return "Loading service geodatabase…"
        case .loadingNetwork: return "Loading utility network…"
        case .startingLocation: return "Getting starting location feature…"
        case .runningTrace: return "Running isolation trace…"
        }
    }
}

#Preview {
    NavigationView {
        RunValveIsolationTraceView()
    }
}
