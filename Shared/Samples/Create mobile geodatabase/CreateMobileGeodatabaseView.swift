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

struct CreateMobileGeodatabaseView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// The point on the map where the user tapped.
    @State private var tapLocation: Point?
    
    /// A Boolean value indicating whether the feature table sheet is showing.
    @State private var tableSheetIsShowing = false
    
    /// A Boolean value indicating whether the file explorer interface is showing
    @State private var fileExporterIsShowing = false
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    var body: some View {
        MapView(map: model.map)
            .onSingleTapGesture { _, mapPoint in
                tapLocation = mapPoint
            }
            .task(id: tapLocation) {
                guard let tapLocation else { return }
                do {
                    // Add a feature at the tap location.
                    try await model.addFeature(at: tapLocation)
                } catch {
                    self.error = error
                }
            }
            .task(id: model.features.isEmpty) {
                do {
                    // Create a new feature table when the features are reset.
                    if model.features.isEmpty {
                        try await model.createFeatureTable()
                    }
                } catch {
                    self.error = error
                }
            }
            .overlay(alignment: .top) {
                Text("Number of features added: \(model.features.count)")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(8)
                    .background(.thinMaterial, ignoresSafeAreaEdges: .horizontal)
            }
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    tableButton
                        .disabled(model.features.isEmpty)
                    
                    Spacer()
                    
                    Button {
                        fileExporterIsShowing = true
                    } label: {
                        Label("Export File", systemImage: "square.and.arrow.up")
                    }
                    .disabled(model.features.isEmpty)
                    .fileExporter(
                        isPresented: $fileExporterIsShowing,
                        document: model.geodatabaseFile,
                        contentType: .geodatabase
                    ) { result in
                        switch result {
                        case .success:
                            do {
                                try model.resetFeatures()
                            } catch {
                                self.error = error
                            }
                        case .failure(let error):
                            self.error = error
                        }
                    }
                }
            }
            .errorAlert(presentingError: $error)
    }
}

private extension CreateMobileGeodatabaseView {
    /// The button that brings up the feature table sheet.
    var tableButton: some View {
        Button("Feature Table") {
            tableSheetIsShowing = true
        }
        .popover(isPresented: $tableSheetIsShowing) {
            tableList
                .presentationDetents([.medium, .large])
                .frame(minWidth: 320, minHeight: 380)
        }
    }
    
    /// The list of features in the feature table.
    private var tableList: some View {
        NavigationStack {
            List {
                Section("OID and Collection Timestamp") {
                    ForEach(model.features, id: \.self) { feature in
                        HStack {
                            Text(String(feature.oid))
                                .padding(.trailing, 8)
                            Text(feature.timestamp.formatted(.collectionTimestamp))
                        }
                    }
                }
            }
            .navigationTitle("Feature Table")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        tableSheetIsShowing = false
                    }
                }
            }
        }
    }
}

private extension FormatStyle where Self == Date.VerbatimFormatStyle {
    /// The format style for a collection timestamp of a feature in a feature table.
    static var collectionTimestamp: Self {
        .init(
            format: """
                \(weekday: .abbreviated) \
                \(month: .abbreviated) \
                \(day: .defaultDigits) \
                \(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .oneBased)):\
                \(minute: .twoDigits):\
                \(second: .twoDigits) \
                \(timeZone: .specificName(.short)) \
                \(year: .defaultDigits)
                """,
            locale: .current,
            timeZone: .current,
            calendar: .current
        )
    }
}

#Preview {
    NavigationStack {
        CreateMobileGeodatabaseView()
    }
}
