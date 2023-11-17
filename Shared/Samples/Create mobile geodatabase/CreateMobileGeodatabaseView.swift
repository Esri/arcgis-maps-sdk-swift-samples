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
    @State private var tapMapPoint = Point(x: 0, y: 0)
    
    /// A Boolean indicating whether the feature table sheet is showing.
    @State private var isShowingTableSheet = false
    
    var body: some View {
        MapView(map: model.map)
            .onSingleTapGesture { _, mapPoint in
                tapMapPoint = mapPoint
            }
            .task {
                // Create the initial geodatabase.
                await model.createGeodatabase()
            }
            .task(id: tapMapPoint) {
                // Add a feature at the tapped map point.
                await model.addFeature(at: tapMapPoint)
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
                    
                    Button {
                        model.presentShareSheet()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .errorAlert(presentingError: $model.error)
    }
}

private extension CreateMobileGeodatabaseView {
    /// The button that brings up the feature table sheet.
    @ViewBuilder var tableButton: some View {
        /// The button to bring up the sheet.
        let button = Button("View Table") {
            isShowingTableSheet = true
        }
        
        if #available(iOS 16, *) {
            button
                .popover(isPresented: $isShowingTableSheet, arrowEdge: .bottom) {
                    tableList
                        .presentationDetents([.fraction(0.5)])
#if targetEnvironment(macCatalyst)
                        .frame(minWidth: 300, minHeight: 270)
#else
                        .frame(minWidth: 320, minHeight: 390)
#endif
                }
        } else {
            button
                .sheet(isPresented: $isShowingTableSheet) {
                    tableList
                }
        }
    }
    
    /// The list of features in the feature table.
    var tableList: some View {
        NavigationView {
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
                        isShowingTableSheet = false
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
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
