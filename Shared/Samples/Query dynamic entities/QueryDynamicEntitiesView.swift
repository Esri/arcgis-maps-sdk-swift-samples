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

struct QueryDynamicEntitiesView: View {
    /// The view model for the sample.
    @State private var model = Model()
    
    /// A Boolean value indicating whether the alert for entering a flight number is showing.
    @State private var flightNumberAlertIsShowing = false
    
    /// The text entered into the flight number alert's text field.
    @State private var flightNumber = ""
    
    /// The type of query currently being performed.
    @State private var selectedQueryType: QueryType?
    
    /// The result of a dynamic entities query operation.
    @State private var queryResult: Result<[DynamicEntity], any Error>?
    
    /// The error shown in the error alert.
    @State private var error: (any Error)?
    
    var body: some View {
        MapView(map: model.map, graphicsOverlays: [model.graphicsOverlay])
            .contentInsets(.init(top: 0, leading: 0, bottom: 250, trailing: 0))
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Spacer()
                    Menu("Query Flights") {
                        Button("Within 15 Miles of PHX", systemImage: "dot.circle") {
                            selectedQueryType = .geometry
                        }
                        Button("Arriving in PHX", systemImage: "airplane.arrival") {
                            selectedQueryType = .attributes
                        }
                        Button("With Flight Number", systemImage: "magnifyingglass") {
                            flightNumberAlertIsShowing = true
                        }
                    }
                    .menuOrder(.fixed)
                    .alert("Enter a Flight Number to Query", isPresented: $flightNumberAlertIsShowing) {
                        TextField("Flight Number", text: $flightNumber)
                        
                        Button("Done") {
                            selectedQueryType = .trackID(flightNumber)
                        }
                        .disabled(flightNumber.isEmpty)
                        
                        Button("Cancel", role: .cancel, action: {})
                    }
                    .task(id: selectedQueryType) {
                        guard let selectedQueryType else { return }
                        queryResult = await model.queryDynamicEntities(type: selectedQueryType)
                    }
                    .popover(item: $selectedQueryType) { queryType in
                        QueryResultView(result: queryResult, type: queryType)
                            .onDisappear(perform: model.resetDisplay)
                            .presentationDetents([.fraction(0.5), .large])
                            .frame(idealWidth: 320, idealHeight: 380)
                    }
                    Spacer()
                }
            }
            .task {
                do {
                    try await model.monitorDataSource()
                } catch {
                    self.error = error
                }
            }
            .errorAlert(presentingError: $error)
    }
}

private extension QueryDynamicEntitiesView {
    /// A view that displays the result of a dynamic entities query operation.
    struct QueryResultView: View {
        /// The result of the dynamic entities query operation.
        let result: Result<[DynamicEntity], any Error>?
        
        /// The type of query that was performed.
        let type: QueryType
        
        /// The action to dismiss the view.
        @Environment(\.dismiss) private var dismiss
        
        var body: some View {
            NavigationStack {
                Group {
                    switch result {
                    case .success(let entities):
                        if !entities.isEmpty {
                            List {
                                Section(type.resultLabel) {
                                    ForEach(entities, id: \.id) { entity in
                                        DynamicEntityObservationView(entity: entity)
                                    }
                                }
                            }
                        } else {
                            ContentUnavailableView(
                                "No Results",
                                systemImage: "airplane",
                                description: .init("There are no flights to display for this query.")
                            )
                        }
                    case .failure(let error):
                        ContentUnavailableView(
                            "Error",
                            systemImage: "exclamationmark.triangle",
                            description: .init(String(reflecting: error))
                        )
                    case nil:
                        ProgressView("Querying dynamic entities")
                    }
                }
                .navigationTitle("Query Results")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            }
        }
    }
    
    /// A view that displays the latest observation of a dynamic entity.
    struct DynamicEntityObservationView: View {
        /// The dynamic entity to observe.
        let entity: DynamicEntity
        
        /// The latest observation's attributes to display.
        @State private var attributes: [String: any Sendable] = [:]
        
        /// A Boolean value indicating whether the dynamic entity has been purged.
        @State private var entityWasPurged = false
        
        /// A Boolean value indicating whether the disclosure group is expanded.
        @State private var isExpanded = false
        
        var body: some View {
            DisclosureGroup(isExpanded: $isExpanded) {
                if !entityWasPurged {
                    let attributes = attributes.sorted(by: { $0.key < $1.key })
                    ForEach(attributes, id: \.key) { name, value in
                        let label = PlaneAttributeKey(rawValue: name)?.label ?? name
                        if let string = value as? String {
                            LabeledContent(label, value: string)
                        } else if let double = value as? Double {
                            LabeledContent(
                                label,
                                value: double,
                                format: .number.precision(.fractionLength(0...2))
                            )
                        }
                    }
                } else {
                    Label(
                        "Entity was purged. Query again to see the latest observation.",
                        systemImage: "exclamationmark.triangle"
                    )
                }
            } label: {
                LabeledContent(entity.attributes["flight_number"] as? String ?? "N/A") {
                    if entityWasPurged {
                        Image(systemName: "exclamationmark.triangle")
                    }
                }
            }
            .task {
                attributes = entity.latestObservation?.attributes ?? [:]
                
                for await changedInfo in entity.changes {
                    attributes = changedInfo.receivedObservation?.attributes ?? [:]
                    entityWasPurged = changedInfo.dynamicEntityWasPurged
                }
            }
        }
    }
}

private extension QueryDynamicEntitiesView.PlaneAttributeKey {
    /// A human-readable label for the attribute.
    var label: String {
        switch self {
        case .aircraft: "Aircraft"
        case .altitudeFeet: "Altitude (ft)"
        case .arrivalAirport: "Arrival Airport"
        case .flightNumber: "Flight Number"
        case .heading: "Heading"
        case .speed: "Speed"
        case .status: "Status"
        }
    }
}

private extension QueryDynamicEntitiesView.QueryType {
    /// The human-readable text describing the query results.
    var resultLabel: String {
        switch self {
        case .geometry: "Flights within 15 miles of PHX"
        case .attributes: "Flights arriving in PHX"
        case .trackID(let trackID): "Flights matching flight number: \(trackID)"
        }
    }
}
