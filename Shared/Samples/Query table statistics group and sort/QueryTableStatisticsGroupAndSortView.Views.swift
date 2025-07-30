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

/// The helper views for `QueryTableStatisticsGroupAndSortView`.
extension QueryTableStatisticsGroupAndSortView {
    /// A view for creating and adding a statistic definition to a given list.
    struct AddStatisticDefinitionView: View {
        /// A binding to the list of statistic definitions to add to.
        @Binding var definitions: [StatisticDefinition]
        
        /// The fields to select a definition field name from.
        let fieldOptions: [String]
        
        /// The action to dismiss the view.
        @Environment(\.dismiss) private var dismiss
        
        /// The field name selected by the "Field" picker.
        @State private var selectedField: String?
        
        /// The statistic type selected by the "Statistic Type" picker.
        @State private var selectedStatisticType = StatisticDefinition.StatisticType.average
        
        /// A Boolean value indicating whether the new definition is a duplicate
        /// of one already found in the definitions list.
        private var definitionIsDuplicate: Bool {
            guard let selectedField else { return false }
            return definitions.contains(where: {
                $0.fieldName == selectedField && $0.statisticType == selectedStatisticType
            })
        }
        
        var body: some View {
            Form {
                Section {
                    NavigationLink {
                        FieldPicker(fields: fieldOptions, selection: $selectedField)
                    } label: {
                        LabeledContent("Field", value: selectedField ?? "Select")
                    }
                    
                    Picker("Statistic Type", selection: $selectedStatisticType) {
                        ForEach(StatisticDefinition.StatisticType.allCases, id: \.self) { type in
                            Text(type.label)
                        }
                    }
                } footer: {
                    if definitionIsDuplicate {
                        Text("Statistic definition must be unique.")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Add Statistic Definition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let newDefinition = StatisticDefinition(
                            fieldName: selectedField!,
                            statisticType: selectedStatisticType
                        )
                        definitions.append(newDefinition)
                        
                        dismiss()
                    }
                    .disabled(selectedField == nil || definitionIsDuplicate)
                }
            }
            .presentationDetents([.fraction(0.5)])
        }
    }
    
    /// A view for adding group by fields to a given list.
    struct AddGroupByFieldsView: View {
        /// A binding to the list of group by fields to add to.
        @Binding var groupByFields: [String]
        
        /// The fields to select from in the list.
        let fieldOptions: [String]
        
        /// The action to dismiss the view.
        @Environment(\.dismiss) private var dismiss
        
        /// The fields selected in the list.
        @State private var selectedFields = Set<String>()
        
        var body: some View {
            List(fieldOptions, id: \.self, selection: $selectedFields) { field in
                Text(field)
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Add Group by Fields")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        groupByFields.append(contentsOf: selectedFields.sorted())
                        dismiss()
                    }
                }
            }
        }
    }
    
    /// A view for creating and adding an order by field to a given list.
    struct AddOrderByFieldView: View {
        /// A binding to the list of order by fields to add to.
        @Binding var orderByFields: [OrderBy]
        
        /// The fields to select an order by field name from.
        let fieldOptions: [String]
        
        /// The action to dismiss the view.
        @Environment(\.dismiss) private var dismiss
        
        /// The field name selected by the "Field" picker.
        @State private var selectedField: String?
        
        /// A Boolean value indicating whether the new order by field will sort
        /// the query results in an ascending order.
        @State private var sortsAscending = true
        
        var body: some View {
            Form {
                NavigationLink {
                    FieldPicker(fields: fieldOptions, selection: $selectedField)
                } label: {
                    LabeledContent("Field", value: selectedField ?? "Select")
                }
                
                Toggle("Sort Ascending", isOn: $sortsAscending)
            }
            .navigationTitle("Add Order by Field")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let sortOrder = sortsAscending ? OrderBy.SortOrder.ascending : .descending
                        let orderBy = OrderBy(fieldName: selectedField!, sortOrder: sortOrder)
                        orderByFields.append(orderBy)
                        
                        dismiss()
                    }
                    .disabled(selectedField == nil)
                }
            }
            .presentationDetents([.fraction(0.5)])
        }
    }
    
    /// A list that displays given statistic records and their statistics.
    struct StatisticRecordsList: View {
        /// The statistic records to show in the list.
        let records: [StatisticRecord]
        
        /// The field names by which to sort the records' group values.
        let groupByFields: [String]
        
        /// The action to dismiss the view.
        @Environment(\.dismiss) private var dismiss
        
        var body: some View {
            List {
                Section(groupByFields.formatted(.list(type: .and, width: .narrow))) {
                    ForEach(records, id: \.objectID) { record in
                        if !record.statistics.isEmpty || !record.group.isEmpty {
                            let groupDescription = record.groupValuesDescription(
                                sortedBy: groupByFields
                            )
                            NavigationLink(groupDescription) {
                                StatisticsList(statistics: record.statistics)
                                    .navigationTitle(groupDescription)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

/// A view for selecting a field name from a given list.
private struct FieldPicker: View {
    /// The field name options to select from.
    let fields: [String]
    
    /// A binding to the currently-selected field name.
    @Binding var selection: String?
    
    /// The action to dismiss the view.
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List(fields, id: \.self, selection: $selection) { field in
            Text(field)
        }
        .navigationTitle("Fields")
        .onChange(of: selection) { dismiss() }
    }
}

/// A list that displays given statistics.
private struct StatisticsList: View {
    /// The statistic names and values to show in the list.
    let statistics: [String: any Sendable]
    
    var body: some View {
        List {
            if !statistics.isEmpty {
                ForEach(statistics.sorted(by: { $0.key < $1.key }), id: \.key) { name, value in
                    if let integer = value as? Int {
                        LabeledContent(name, value: integer, format: .number)
                    } else if let double = value as? Double {
                        LabeledContent(name, value: double, format: .number)
                    }
                }
            } else {
                ContentUnavailableView(
                    "No Statistics",
                    systemImage: "list.bullet",
                    description: Text("There are no statistics for this record.")
                )
            }
        }
    }
}

// MARK: - Extensions

private extension StatisticRecord {
    /// Returns the description of the records group value.
    /// - Parameter groupByFields: The field names by which to sort the group
    /// values.
    func groupValuesDescription(sortedBy groupByFields: [String]) -> String {
        let groupValues = groupByFields.compactMap { field in
            if let value = group[field] {
                "\(value)"
            } else {
                nil
            }
        }
        
        return groupValues.formatted(.list(type: .and, width: .narrow))
    }
}

private extension StatisticDefinition.StatisticType {
    /// All of the statistic type cases.
    static var allCases: [Self] {
        return [average, count, maximum, minimum, standardDeviation, sum, variance]
    }
}

private extension StatisticRecord {
    /// The identifier for the statistic record object.
    var objectID: ObjectIdentifier { .init(self) }
}
