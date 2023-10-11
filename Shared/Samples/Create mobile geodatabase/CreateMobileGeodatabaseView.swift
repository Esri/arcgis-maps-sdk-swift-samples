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
    
    ///
    @State private var isShowingTable = false
    
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
                await model.addFeature(at: tapMapPoint)
            }
            .overlay(alignment: .top) {
                Text("Number of features added: \(model.featureCount)")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(8)
                    .background(.thinMaterial, ignoresSafeAreaEdges: .horizontal)
            }
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button("View Table") {
                        Task {
                            await model.updateFeatures()
                            isShowingTable = true
                        }
                    }
                    .sheet(isPresented: $isShowingTable, detents: [.medium]) {
                        tableList
                    }
                    .disabled(model.featureCount == 0)
                    
                    Button("Create and Share") {
                        print("yea")
                    }
                }
            }
            .alert(isPresented: $model.isShowingErrorAlert, presentingError: model.error)
    }
    
    var tableList: some View {
        NavigationView {
            List {
                Section("OID and Collection Timestamp") {
                    ForEach(model.features, id: \.self) { row in
                        HStack {
                            Text(String(row.oid))
                            Spacer()
                            Text(row.timeStamp.formatted(.collectionTimestamp))
                        }
                    }
                }
            }
            .navigationTitle("Feature Table")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isShowingTable = false
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

private extension FormatStyle where Self == Date.VerbatimFormatStyle {
    /// The format style for a collection timestamp.
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

struct CreateMobileGeodatabaseView_Previews: PreviewProvider {
    static var previews: some View {
        CreateMobileGeodatabaseView()
    }
}
