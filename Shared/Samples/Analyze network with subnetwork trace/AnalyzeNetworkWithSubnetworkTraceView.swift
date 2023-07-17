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
    @State var selectedAttribute: UtilityNetworkAttribute?
    
    /// The comparison selected by the user.
    @State var selectedComparison: UtilityNetworkAttributeComparison.Operator?
    
    /// The value selected by the user.
    @State var selectedValue: Any?
    
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
    
    var body: some View {
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
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) { toolbarItems }
        }
        .task {
            await model.setup()
        }
        .alert(isPresented: $model.isShowingSetupError, presentingError: model.setupError)
        .alert(isPresented: $model.isShowingTracingError, presentingError: model.tracingError)
        .alert(isPresented: $model.isShowingCreateExpressionError, presentingError: model.createExpressionError)
        .alert("Trace Result", isPresented: $presentTraceResults, actions: {}, message: {
            let elementString = model.traceResultsCount == 0 ? "No" : model.traceResultsCount.formatted()
            Text("\(elementString) element(s) found.")
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
        .overlay(alignment: .center) {
            if !model.statusText.isEmpty {
                ZStack {
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
        } label: {
            Image(systemName: "plus")
                .imageScale(.large)
        }
        Spacer()
        Button("Trace") {
            Task {
                await model.trace(includeBarriers: includesBarriers, includeContainers: includesContainers)
                presentTraceResults = true
            }
        }
        .disabled(!model.traceEnabled)
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
                        .onSubmit {
                            selectedValue = inputValue
                        }
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
                    model.addConditionalExpression(
                        attribute: attribute,
                        comparison: comparison,
                        value: value
                    )
                    selectedAttribute = nil
                    selectedComparison = nil
                    selectedValue = nil
                    inputValue = nil
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
            .navigationTitle("Attributes")
        }
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
