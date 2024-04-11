// Copyright 2024 Esri
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

extension ValidateUtilityNetworkTopologyView {
    /// A view allowing a user to edit the attribute field value of the feature.
    struct EditFeatureView: View {
        /// The view model for the sample.
        @ObservedObject var model: Model
        
        /// The current view model operation being executed.
        @Binding var operationSelection: ModelOperation
        
        /// The action to dismiss the view.
        @Environment(\.dismiss) private var dismiss: DismissAction
        
        var body: some View {
            NavigationView {
                fieldValuePicker
                    .navigationTitle("Edit Feature")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                dismiss()
                            }
                        }
                        
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Apply") {
                                operationSelection = .applyEdits
                                dismiss()
                            }
                        }
                    }
            }
            .navigationViewStyle(.stack)
        }
        
        /// The picker for the field value options.
        private var fieldValuePicker: some View {
            Form {
                Section(model.field?.alias ?? "Field") {
                    ForEach(model.fieldValueOptions, id: \.name) { option in
                        Button {
                            model.selectedFieldValue = option
                        } label: {
                            HStack {
                                Text(option.name)
                                Spacer()
                                if option.name == model.selectedFieldValue?.name {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    /// Text with a button for collapsing multiple lines into a single one.
    struct CollapsibleText: View {
        /// The text to show.
        @Binding var text: String
        
        /// A Boolean value indicating whether the message is presented.
        @State private var messageIsPresented = false
        
        /// The first line of the text.
        private var title: String {
            text.components(separatedBy: .newlines).first ?? text
        }
        
        /// The text without the title.
        private var message: String {
            var lines = text.components(separatedBy: .newlines)
            lines.removeFirst()
            return lines.joined(separator: "\n")
        }
        
        var body: some View {
            VStack {
                HStack {
                    Spacer()
                    Text(title)
                        .fontWeight(messageIsPresented ? .bold : .regular)
                    Spacer()
                    Button {
                        withAnimation {
                            messageIsPresented.toggle()
                        }
                    } label: {
                        Image(systemName: messageIsPresented ? "x" : "chevron.down")
                            .symbolVariant(.circle)
                    }
                    .disabled(message.isEmpty)
                }
                
                if messageIsPresented {
                    Text(message)
                }
            }
            .multilineTextAlignment(.center)
            .onChange(of: text) { _ in
                // Start with the full text showing to notify the user of the change.
                messageIsPresented = !message.isEmpty
            }
        }
    }
}
