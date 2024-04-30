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

extension EditWithBranchVersioningView {
    /// A view that creates service version parameters from user inputs.
    struct CreateVersionParametersView: View {
        /// The view model for the sample.
        @ObservedObject var model: Model
        
        /// The action to preform when the parameters are created, i.e, when the "Done" button is pressed.
        let action: (ServiceVersionParameters) -> Void
        
        /// The action to dismiss the view.
        @Environment(\.dismiss) private var dismiss
        
        /// The name of the version entered by the user.
        @State private var versionName = ""
        
        /// The description of the version entered by the user.
        @State private var versionDescription = ""
        
        /// The version access for the version selected by the user.
        @State private var selectedVersionAccess: VersionAccess?
        
        /// The text describing an issue with the user entered version name.
        @State private var nameValidateError: String?
        
        /// A Boolean value indicating whether all the user inputs are valid.
        private var inputsAreValid: Bool {
            !versionName.isEmpty && nameValidateError == nil && selectedVersionAccess != nil
        }
        
        var body: some View {
            NavigationStack {
                Form {
                    Section {
                        TextField("Name", text: $versionName)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .onChange(of: versionName) {
                                nameValidateError = validateVersionName($0)
                            }
                    } header: {
                        Text("Name")
                    } footer: {
                        if let nameValidateError {
                            Text(nameValidateError)
                                .foregroundColor(.red)
                        }
                    }
                    
                    Section("Description") {
                        TextField("Description", text: $versionDescription)
                    }
                    
                    Section {
                        Picker("Access Permissions", selection: $selectedVersionAccess) {
                            ForEach(VersionAccess.allCases, id: \.self) { versionAccess in
                                Text("\(versionAccess)".capitalized)
                                    .tag(versionAccess as VersionAccess?)
                            }
                        }
                        .pickerStyle(.segmented)
                    } header: {
                        Text("Access Permissions")
                    } footer: {
                        if let selectedVersionAccess {
                            Text(selectedVersionAccess.description)
                        }
                    }
                }
                .navigationTitle("Create Version")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            model.clearSelection()
                            dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            let parameters = ServiceVersionParameters()
                            parameters.access = selectedVersionAccess!
                            parameters.name = versionName
                            parameters.description = versionDescription
                            
                            action(parameters)
                            dismiss()
                        }
                        .disabled(!inputsAreValid)
                    }
                }
            }
        }
        
        /// Validates a given name to ensure it meets the criteria for a version name.
        /// - Parameter name: The name to validate.
        /// - Returns: Text describing the broken validation rule, if any.
        private func validateVersionName(_ name: String) -> String? {
            if name.isEmpty {
                return "Name is required"
            } else if name.count > 62 {
                return "Name must not exceed 62 characters"
            } else if name.first == " " {
                return "Name must not begin with a space."
            } else if name.contains(";") {
                return "Name must not contain semicolons (;)"
            } else if name.contains(".") {
                return "Name must not contain periods (.)"
            } else if name.contains("'") {
                return "Name must not contain single quotation marks (')"
            } else if name.contains("\"") {
                return "Name must not contain double quotation marks (\")"
            } else if model.existingVersionNames.contains(name) {
                return "Version already exists"
            } else {
                return nil
            }
        }
    }
}

private extension VersionAccess {
    /// All the version access cases.
    static var allCases: [Self] { [.public, .protected, .private] }
    
    /// The text description of the version access.
    var description: String {
        switch self {
        case .public: return "Any portal user can view and edit the version."
        case .protected: return "Any portal user can view the version, but only the version owner, feature layer owner, and portal administrator can edit it."
        case .private: return "Only the version owner, feature layer owner, and portal administrator can view and edit the version."
        @unknown default: return "Unknown version access."
        }
    }
}
