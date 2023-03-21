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

extension DownloadPreplannedMapAreaView {
    struct MapPicker: View {
        /// The action to dismiss the sheet.
        @Environment(\.dismiss) private var dismiss
        
        /// The view model for the download preplanned map area view.
        @EnvironmentObject private var model: Model
        
        var body: some View {
            NavigationView {
                List {
                    Section {
                        Picker("Web Maps (Online)", selection: $model.selectedMap) {
                            Text("Web Map (Online)")
                                .tag(Model.SelectedMap.onlineWebMap)
                        }
                        .labelsHidden()
                        .pickerStyle(.inline)
                    }
                    
                    Section {
                        
                        switch model.offlineMapInfos {
                        case .success(let infos):
                            Picker("Preplanned Map Areas", selection: $model.selectedMap) {
                                ForEach(infos, id: \.preplannedMapArea.portalItem.id) { offlineMapInfo in
                                    HStack {
                                        if let job = offlineMapInfo.job {
                                            ProgressView(job.progress)
                                                .progressViewStyle(.gauge)
                                        }
                                        Text(offlineMapInfo.preplannedMapArea.portalItem.title)
                                    }
                                    .tag(Model.SelectedMap.offlineMap(offlineMapInfo))
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.inline)
                        case .failure(let error):
                            // Error getting the offline infos.
                            Text(error.localizedDescription)
                        case .none:
                            // Getting the offline infos is still in progress.
                            ProgressView()
                        }
                        
                    } header: {
                        Text("Preplanned Map Areas")
                    } footer: {
                        Text(
                            """
                            Tap to download a preplanned map area for offline use. Once the selected \
                            map is downloaded, the map will update with the offline map's area.
                            """
                        )
                    }
                }
                .navigationTitle("Select Map")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            }
            .navigationViewStyle(.stack)
        }
    }
}

/// A circular gauge progress view style.
private struct GaugeProgressViewStyle: ProgressViewStyle {
    private var strokeStyle: StrokeStyle { .init(lineWidth: 3, lineCap: .round) }
    
    func makeBody(configuration: Configuration) -> some View {
        if let fractionCompleted = configuration.fractionCompleted {
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), style: strokeStyle)
                Circle()
                    .trim(from: 0, to: fractionCompleted)
                    .stroke(.gray, style: strokeStyle)
                    .rotationEffect(.degrees(-90))
            }
            .fixedSize()
        }
    }
}

private extension ProgressViewStyle where Self == GaugeProgressViewStyle {
    /// A progress view that visually indicates its progress with a gauge.
    static var gauge: Self { .init() }
}
