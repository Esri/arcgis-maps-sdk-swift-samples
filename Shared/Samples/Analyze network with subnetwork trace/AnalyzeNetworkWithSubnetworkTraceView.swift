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

import SwiftUI
import ArcGIS

struct AnalyzeNetworkWithSubnetworkTraceView: View {
    /// The view model for the sample.
    @StateObject var model = Model()
    
    /// A Boolean value indicating if the add condition menu is presented.
    @State var isConditionMenuPresented = false
    
    /// A Boolean value indicating whether the input box is showing.
    @State var inputBoxIsPresented = false
    
    /// The value input by the user.
    @State var inputValue: Double?
    
    /// A Boolean value indicating if the trace results should be presented in an alert.
    @State var presentTraceResults = false
    
    /// A Boolean value indicating whether to include barriers in the trace results.
    @State var includesBarriers = true
    
    /// A Boolean value indicating whether to include containment features in the trace results.
    @State var includesContainers = true
    
    var body: some View {
        settingsView
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button("Reset") {
                        model.reset()
                    }
                    .disabled(!model.resetEnabled)
                    Spacer()
                    Button {
                        isConditionMenuPresented.toggle()
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
            }
            .task {
                await model.setup()
            }
            .alert(isPresented: $model.isShowingSetupError, presentingError: model.setupError)
            .alert(isPresented: $model.isShowingTracingError, presentingError: model.tracingError)
            .alert(isPresented: $model.isShowingCreateExpressionError, presentingError: model.createExpressionError)
            .alert("Trace Result", isPresented: $presentTraceResults, actions: {}, message: {
                Text("\(model.traceResultsCount?.description ?? "No") element(s) found.")
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
                if let statusText = model.statusText {
                    ZStack {
                        Color.clear.background(.ultraThinMaterial)
                        VStack {
                            Text(statusText)
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
    
    @ViewBuilder var settingsView: some View {
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
                Text("List of conditions")
            } footer: {
                Text(model.expressionString)
            }
        }
    }
    
    @ViewBuilder var conditionMenu: some View {
        List {
            NavigationLink {
                attributesView
            } label: {
                Text("Attributes")
                Spacer()
                Text(model.selectedAttribute?.name ?? "")
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            NavigationLink {
                operatorsView
            } label: {
                Text("Comparison")
                Spacer()
                Text(model.selectedComparison?.title ?? "")
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            if model.selectedAttribute?.domain as? CodedValueDomain != nil {
                HStack {
                    NavigationLink {
                        valuesView
                    } label: {
                        Text("Value")
                        Spacer()
                        if let value = model.selectedValue as? CodedValue {
                            Text(value.name)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                }
                .disabled(model.selectedAttribute == nil && model.selectedComparison == nil)
            } else {
                HStack {
                    Text("Value")
                    Spacer()
                    if let value = inputValue {
                        Text(value.formatted())
                    }
                }
                .contentShape(Rectangle())
                .disabled(model.selectedAttribute == nil && model.selectedComparison == nil)
                .onTapGesture {
                    inputBoxIsPresented = true
                }
                .alert("Provide a comparison value", isPresented: $inputBoxIsPresented, actions: {
                    TextField("10", value: $inputValue, format: .number)
                        .keyboardType(.numberPad)
                    Button("Done") {
                        inputBoxIsPresented = false
                        model.selectedValue = inputValue
                    }
                    Button("Cancel") {
                        inputBoxIsPresented = false
                        model.selectedValue = nil
                        inputValue = nil
                    }
                })
            }
        }
        .navigationTitle("Add Condition")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    isConditionMenuPresented.toggle()
                    model.addConditionalExpression()
                    model.selectedValue = nil
                    inputValue = nil
                }
                .disabled(
                    model.selectedAttribute == nil ||
                    model.selectedComparison == nil ||
                    model.selectedValue == nil
                )
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    isConditionMenuPresented.toggle()
                    model.clearSelection()
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
                if attribute === model.selectedAttribute {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                model.selectedAttribute = attribute
            }
        }
    }
    
    @ViewBuilder var operatorsView: some View {
        Section {
            List(model.attributeComparisonOperators, id: \.self) { comparison in
                HStack {
                    Text(comparison.title)
                    Spacer()
                    if comparison == model.selectedComparison {
                        Image(systemName: "checkmark")
                            .foregroundColor(.accentColor)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    model.selectedComparison = comparison
                }
            }
        }
    }
    
    @ViewBuilder var valuesView: some View {
        if let domain = model.selectedAttribute?.domain as? CodedValueDomain {
            Section {
                List(domain.codedValues, id: \.name) { value in
                    HStack {
                        Text(value.name)
                        Spacer()
                        if value === model.selectedValue as? CodedValue {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        model.selectedValue = value
                    }
                }
            }
        }
    }
}
