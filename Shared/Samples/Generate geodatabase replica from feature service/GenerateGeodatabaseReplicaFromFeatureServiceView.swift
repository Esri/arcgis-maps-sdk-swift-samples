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
import SwiftUI

struct GenerateGeodatabaseReplicaFromFeatureServiceView: View {
    /// The view model for the sample.
    @State private var model = Model()
    
    /// The text describing the status of the sample.
    @State private var statusText = ""
    
    /// A Boolean value indicating whether the geodatabase is being generated.
    @State private var isGeneratingGeodatabase = false
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    var body: some View {
        GeometryReader { geometryProxy in
            MapViewReader { mapViewProxy in
                MapView(map: model.map)
                    .task {
                        do {
                            try await model.setUpMap()
                            statusText = "Tap the generate button to take the area offline."
                        } catch {
                            self.error = error
                        }
                    }
                    .overlay(alignment: .top) {
                        VStack {
                            Text(statusText)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(8)
                                .background(.regularMaterial, ignoresSafeAreaEdges: .horizontal)
                            
                            // The red rectangle representing the extent of data to include in the geodatabase.
                            Rectangle()
                                .stroke(.red, lineWidth: 2)
                                .padding(EdgeInsets(top: 20, leading: 20, bottom: 44, trailing: 20))
                                .opacity(model.geodatabase == nil ? 1 : 0)
                        }
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .bottomBar) {
                            Button("Generate Geodatabase") {
                                isGeneratingGeodatabase = true
                            }
                            .disabled(isGeneratingGeodatabase || model.geodatabase != nil)
                        }
                    }
                    .task(id: isGeneratingGeodatabase) {
                        guard isGeneratingGeodatabase else { return }
                        defer { isGeneratingGeodatabase = false }
                        
                        do {
                            // Creates an envelope from the area of interest.
                            let viewRect = geometryProxy.frame(in: .local).inset(
                                by: UIEdgeInsets(
                                    top: 20,
                                    left: geometryProxy.safeAreaInsets.leading + 20,
                                    bottom: 44,
                                    right: -geometryProxy.safeAreaInsets.trailing + 20
                                )
                            )
                            guard let extent = mapViewProxy.envelope(
                                fromViewRect: viewRect
                            ) else { return }
                            
                            // Generates the geodatabase using the envelope.
                            try await model.generateGeodatabase(extent: extent)
                            statusText = "Generated geodatabase successfully."
                        } catch {
                            self.error = error
                        }
                    }
                    .overlay(alignment: .center) {
                        // Shows a progress view when there is a job currently running.
                        if let progress = model.generateGeodatabaseJob?.progress {
                            VStack {
                                Text("Creating geodatabase…")
                                    .padding(.bottom)
                                
                                ProgressView(progress)
                                    .frame(maxWidth: 180)
                            }
                            .padding()
                            .background(.ultraThickMaterial)
                            .clipShape(.rect(cornerRadius: 10))
                            .shadow(radius: 50)
                        }
                    }
                    .onDisappear {
                        Task { await model.cancelJob() }
                    }
                    .errorAlert(presentingError: $error)
            }
        }
    }
}

#Preview {
    GenerateGeodatabaseReplicaFromFeatureServiceView()
}
