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

struct AnalyzeNetworkWithSubnetworkTraceView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// The attribute selected by the user.
    @State private var selectedAttribute: UtilityNetworkAttribute?
    
    /// The comparison selected by the user.
    @State private var selectedComparison: UtilityNetworkAttributeComparison.Operator?
    
    /// The value selected by the user.
    @State private var selectedValue: Any?
    
    /// A Boolean value indicating if the add condition menu is presented.
    @State private var isConditionMenuPresented = false
    
    /// A Boolean value indicating whether the input box is showing.
    @State private var inputBoxIsPresented = false
    
    /// The value input by the user.
    @State private var inputValue: Double?
    
    /// A Boolean value indicating if the trace results should be presented in an alert.
    @State private var presentTraceResults = false
    
    /// A Boolean value indicating whether to include barriers in the trace results.
    @State private var includesBarriers = true
    
    /// A Boolean value indicating whether to include containment features in the trace results.
    @State private var includesContainers = true
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    var body: some View {
        if !model.isSetUp {
            loadingView
                .task {
                    do {
                        try await model.setup()
                    } catch {
                        self.error = error
                    }
                }
        } else {
            Form {
                Section("Trace Options") {
                    Toggle("Includes barriers", isOn: $includesBarriers)
                    Toggle("Includes containers", isOn: $includesContainers)
                }
                Section {
                    ForEach(model.conditions, id: \.self) { condition in
                        Text(condition)
                    }
                    .onDelete { indexSet in
                        model.deleteConditionalExpression(atOffsets: indexSet)
                    }
                } header: {
                    Text("Conditions")
                } footer: {
                    Text(model.expressionString)
                }
            }
            .alert("Trace Result", isPresented: $presentTraceResults, actions: {}, message: {
                if model.traceResultsCount == 0 {
                    Text("No element found.")
                } else {
                    Text("\(model.traceResultsCount, format: .number) element(s) found.")
                }
            })
            .sheet(isPresented: $isConditionMenuPresented) {
                if #available(iOS 16, *) {
                    NavigationStack {
                        conditionMenu
                    }
                } else {
                    NavigationView {
                        conditionMenu
                    }
                }
            }
            .overlay(alignment: .center) { loadingView }
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) { toolbarItems }
            }
        }
    }
    
    @ViewBuilder var toolbarItems: some View {
        Button("Reset") {
            model.reset()
        }
        .disabled(model.conditions.count == 1)
        Spacer()
        Button {
            isConditionMenuPresented = true
            inputValue = nil
        } label: {
            Image(systemName: "plus")
                .imageScale(.large)
        }
        Spacer()
        Button("Trace") {
            Task {
                do {
                    try await model.trace(includeBarriers: includesBarriers, includeContainers: includesContainers)
                    presentTraceResults = true
                } catch {
                    self.error = error
                }
            }
        }
        .disabled(!model.traceEnabled)
    }
    
    @ViewBuilder var loadingView: some View {
        ZStack {
            if !model.statusText.isEmpty {
                Color.clear.background(.ultraThinMaterial)
                VStack {
                    Text(model.statusText)
                    ProgressView()
                        .progressViewStyle(.circular)
                }
                .padding()
                .background(.ultraThickMaterial)
                .cornerRadius(10)
                .shadow(radius: 50)
            }
        }
        .errorAlert(presentingError: $error)
    }
    
    @ViewBuilder var conditionMenu: some View {
        List {
            NavigationLink {
                attributesView
            } label: {
                HStack {
                    Text("Attributes")
                    if let selectedAttribute = selectedAttribute {
                        Spacer()
                        Text(selectedAttribute.name)
                            .foregroundColor(.secondary)
                    }
                }
            }
            NavigationLink {
                operatorsView
            } label: {
                HStack {
                    Text("Comparison")
                    if let selectedComparison = selectedComparison {
                        Spacer()
                        Text(selectedComparison.title)
                            .foregroundColor(.secondary)
                    }
                }
            }
            if selectedAttribute?.domain as? CodedValueDomain != nil {
                NavigationLink {
                    valuesView
                } label: {
                    HStack {
                        Text("Value")
                        if let value = selectedValue as? CodedValue {
                            Spacer()
                            Text(value.name)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .disabled(selectedAttribute == nil && selectedComparison == nil)
            } else {
                HStack {
                    Text("Value")
                    TextField("Comparison value", value: $inputValue, format: .number, prompt: Text("Value"))
                        .multilineTextAlignment(.trailing)
                        .lineLimit(1)
                }
                .onChange(of: inputValue) { value in
                    selectedValue = value
                }
                .disabled(selectedAttribute == nil && selectedComparison == nil)
            }
        }
        .navigationTitle("Add Condition")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    isConditionMenuPresented = false
                    guard let attribute = selectedAttribute,
                          let comparison = selectedComparison,
                          let value = selectedValue else {
                        // show error
                        return
                    }
                    do {
                        try model.addConditionalExpression(
                            attribute: attribute,
                            comparison: comparison,
                            value: value
                        )
                        selectedAttribute = nil
                        selectedComparison = nil
                        selectedValue = nil
                        inputValue = nil
                    } catch {
                        self.error = error
                    }
                }
                .disabled(
                    selectedAttribute == nil ||
                    selectedComparison == nil ||
                    selectedValue == nil
                )
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    isConditionMenuPresented = false
                    selectedAttribute = nil
                    selectedComparison = nil
                    selectedValue = nil
                    inputValue = nil
                }
            }
        }
        .navigationViewStyle(.stack)
    }
    
    @ViewBuilder var attributesView: some View {
        List(model.possibleAttributes, id: \.name) { attribute in
            HStack {
                Text(attribute.name)
                Spacer()
                if attribute === selectedAttribute {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                selectedAttribute = attribute
            }
        }
        .navigationTitle("Attributes")
    }
    
    @ViewBuilder var operatorsView: some View {
        Section {
            List(UtilityNetworkAttributeComparison.Operator.allCases, id: \.self) { comparison in
                HStack {
                    Text(comparison.title)
                    Spacer()
                    if comparison == selectedComparison {
                        Image(systemName: "checkmark")
                            .foregroundColor(.accentColor)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedComparison = comparison
                }
            }
        }
        .navigationTitle("Operators")
    }
    
    @ViewBuilder var valuesView: some View {
        if let domain = selectedAttribute?.domain as? CodedValueDomain {
            Section {
                List(domain.codedValues, id: \.name) { value in
                    HStack {
                        Text(value.name)
                        Spacer()
                        if value === selectedValue as? CodedValue {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedValue = value
                    }
                }
            }
            .navigationTitle("Values")
        }
    }
}

private extension UtilityNetworkAttributeComparison.Operator {
    static var allCases: [UtilityNetworkAttributeComparison.Operator] { [.equal, .notEqual, .greaterThan, .greaterThanEqual, .lessThan, .lessThanEqual, .includesTheValues, .doesNotIncludeTheValues, .includesAny, .doesNotIncludeAny]
    }
}

#Preview {
    NavigationView {
        AnalyzeNetworkWithSubnetworkTraceView()
    }
}
