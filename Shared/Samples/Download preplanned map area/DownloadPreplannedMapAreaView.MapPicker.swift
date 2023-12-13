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
        @ObservedObject var model: Model
        
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
                        switch model.offlineMapModels {
                        case .success(let models):
                            Picker("Preplanned Map Areas", selection: $model.selectedMap) {
                                ForEach(models) { model in
                                    PreplannedMapAreaSelectionView(model: model)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.inline)
                        case .failure(let error):
                            // Error getting the offline map models.
                            Text(error.localizedDescription)
                        case .none:
                            // Getting the offline map models is still in progress.
                            ProgressView().frame(maxWidth: .infinity)
                        }
                    } header: {
                        Text("Preplanned Map Areas")
                    } footer: {
                        Text(
                            """
                            Tap to download a preplanned map area for offline use. Once downloaded, \
                            tap it again to select and open it.
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
    
    /// A view that displays preplanned map areas available for download.
    private struct PreplannedMapAreaSelectionView: View {
        /// The model that drives this view.
        @ObservedObject var model: OfflineMapModel
        
        var body: some View {
            HStack {
                if model.isDownloading, let job = model.job {
                    ProgressView(job.progress)
                        .progressViewStyle(.gauge)
                    Text(model.preplannedMapArea.portalItem.title)
                } else {
                        switch model.result {
                        case .success:
                            EmptyView()
                        case .failure:
                            Image(systemName: "exclamationmark.circle")
                                .foregroundColor(.red)
                        case .none:
                            Image(systemName: "tray.and.arrow.down")
                                .foregroundColor(.accentColor)
                        }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.preplannedMapArea.portalItem.title)
                            .foregroundColor(titleColor(for: model.result))
                        
                        // If failed then show tap to retry text.
                        if case .failure = model.result {
                            Text("Error occurred. Tap to retry.")
                                .font(.caption2)
                        }
                    }
                }
            }
            .tag(Model.SelectedMap.offlineMap(model))
        }
        
        /// The color of the title for a given result.
        func titleColor(for result: Result<MobileMapPackage, Error>?) -> Color {
            switch model.result {
            case .success:
                return .primary
            case .failure, .none:
                return .secondary
            }
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
