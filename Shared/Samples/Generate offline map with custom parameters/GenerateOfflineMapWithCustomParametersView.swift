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

struct GenerateOfflineMapWithCustomParametersView: View {
    /// A Boolean value indicating whether the job is generating an offline map.
    @State private var isGeneratingOfflineMap = false
    
    /// A Boolean value indicating whether the job is cancelling.
    @State private var isCancellingJob = false
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    /// The view model for this sample.
    @StateObject private var model = Model()
    
    /// A Boolean value indicating whether to set the custom parameters.
    @State private var isShowingSetCustomParameters = false
    
    var body: some View {
        GeometryReader { geometry in
            MapViewReader { mapView in
                MapView(map: model.offlineMap ?? model.onlineMap)
                    .interactionModes(isGeneratingOfflineMap ? [] : [.pan, .zoom])
                    .errorAlert(presentingError: $error)
                    .task {
                        do {
                            try await model.initializeOfflineMapTask()
                        } catch {
                            self.error = error
                        }
                    }
                    .onDisappear {
                        Task { await model.cancelJob() }
                    }
                    .overlay {
                        Rectangle()
                            .stroke(.red, lineWidth: 2)
                            .padding(EdgeInsets(top: 20, leading: 20, bottom: 44, trailing: 20))
                            .opacity(model.offlineMap == nil ? 1 : 0)
                    }
                    .overlay {
                        if isGeneratingOfflineMap,
                           let progress = model.generateOfflineMapJob?.progress {
                            VStack(spacing: 16) {
                                ProgressView(progress)
                                    .progressViewStyle(.linear)
                                    .frame(maxWidth: 200)
                                
                                Button("Cancel") {
                                    isCancellingJob = true
                                }
                                .disabled(isCancellingJob)
                                .task(id: isCancellingJob) {
                                    guard isCancellingJob else { return }
                                    // Cancels the job.
                                    await model.cancelJob()
                                    // Sets cancelling the job and generating an
                                    // offline map to false.
                                    isCancellingJob = false
                                    isGeneratingOfflineMap = false
                                }
                            }
                            .padding()
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                            .shadow(radius: 3)
                        }
                    }
                    .overlay(alignment: .top) {
                        Text("Offline map generated.")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(8)
                            .background(.thinMaterial, ignoresSafeAreaEdges: .horizontal)
                            .opacity(model.offlineMap != nil ? 1 : 0)
                    }
                    .toolbar {
                        ToolbarItem(placement: .bottomBar) {
                            Button("Generate Offline Map") {
                                isShowingSetCustomParameters.toggle()
                            }
                            .disabled(model.isGenerateDisabled || isGeneratingOfflineMap)
                            .popover(isPresented: $isShowingSetCustomParameters) {
                                // Creates a rectangle from the area of interest.
                                let viewRect = geometry.frame(in: .local).inset(
                                    by: UIEdgeInsets(
                                        top: 20,
                                        left: geometry.safeAreaInsets.leading + 20,
                                        bottom: 44,
                                        right: -geometry.safeAreaInsets.trailing + 20
                                    )
                                )
                                // Creates an envelope from the rectangle.
                                if let extent = mapView.envelope(fromViewRect: viewRect) {
                                    CustomParameters(
                                        model: model,
                                        extent: extent,
                                        isGeneratingOfflineMap: $isGeneratingOfflineMap
                                    )
                                    .presentationDetents([.fraction(1.0)])
                                    .frame(idealWidth: 320, idealHeight: 720)
                                }
                            }
                            .task(id: isGeneratingOfflineMap) {
                                guard isGeneratingOfflineMap else { return }
                                
                                do {
                                    // Generates an offline map.
                                    try await model.generateOfflineMap()
                                } catch {
                                    self.error = error
                                }
                                
                                // Sets generating an offline map to false.
                                isGeneratingOfflineMap = false
                            }
                        }
                    }
            }
        }
    }
}

#Preview {
    NavigationStack {
        GenerateOfflineMapWithCustomParametersView()
    }
}
