// Copyright 2022 Esri
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

struct DownloadPreplannedMapAreaView: View {
    /// A Boolean value indicating whether the sample info view is visible.
    @Environment(\.isSampleInfoViewVisible) private var isSampleInfoViewVisible
    
    /// A Boolean value indicating whether to select a map.
    @State private var isSelectingMap = false
    
    /// A Boolean value indicating whether to show delete alert.
    @State private var isShowingDeleteAlert = false
    
    /// The view model for this sample.
    @StateObject private var model = Model()
    
    var body: some View {
        MapView(map: model.map)
            .alert(isPresented: $model.isShowingErrorAlert, presentingError: model.error)
            .overlay(alignment: .top) {
                Text("Current map: \(model.map.item?.title ?? "Unknown")")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(.thinMaterial, ignoresSafeAreaEdges: .horizontal)
            }
            .task {
                await model.loadPreplannedMapAreas()
            }
            .onDisappear {
                if !isSampleInfoViewVisible {
                    Task { await model.cancelAllJobs() }
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Spacer()
                    Button("Select Map") {
                        isSelectingMap.toggle()
                    }
                    .sheet(isPresented: $isSelectingMap, detents: [.medium]) {
                        MapPicker()
                            .environmentObject(model)
                    }
                    Spacer()
                    Button {
                        isShowingDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(model.localMapPackages.isEmpty)
                    .alert("Delete All Offline Areas", isPresented: $isShowingDeleteAlert) {
                        Button("Delete", role: .destructive) {
                            model.removeDownloadedMaps()
                        }
                    } message: {
                        Text("Are you sure you want to delete all downloaded preplanned map areas?")
                    }
                }
            }
    }
}
