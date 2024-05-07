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
        
        /// The action to perform when the parameters are created, i.e, when the "Done" button is pressed.
        let action: (ServiceVersionParameters) -> Void
        
        /// The action to dismiss the view.
        @Environment(\.dismiss) private var dismiss
        
        /// The name of the version entered by the user.
        @State private var versionName = ""
        
        /// The description of the version entered by the user.
        @State private var versionDescription = ""
        
        /// The version access for the version selected by the user.
        @State private var selectedVersionAccess: VersionAccess = .public
        
        var body: some View {
            NavigationStack {
                Form {
                    TextField("Name", text: $versionName)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: versionName) { newVersionName in
                            // Ensures the inputted version name is valid.
                            let formattedVersionName = newVersionName
                                .replacing(/[.;'"]/, with: "")
                                .prefix(62)
                            
                            self.versionName = String(formattedVersionName)
                        }
                    
                    TextField("Description", text: $versionDescription )
                    
                    Picker("Access Permissions", selection: $selectedVersionAccess) {
                        ForEach(VersionAccess.allCases, id: \.self) { versionAccess in
                            Text(versionAccess.label)
                        }
                    }
                }
                .navigationTitle("New Version")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", role: .cancel) {
                            model.clearSelection()
                            dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            let parameters = ServiceVersionParameters()
                            parameters.access = selectedVersionAccess
                            parameters.name = versionName
                            parameters.description = versionDescription
                            
                            action(parameters)
                            dismiss()
                        }
                        .disabled(versionName.isEmpty)
                    }
                }
            }
        }
    }
}

private extension VersionAccess {
    /// All the version access cases.
    static var allCases: [Self] { [.public, .protected, .private] }
    
    /// A human-readable label for the version access.
    var label: String {
        switch self {
        case .public: "Public"
        case .protected: "Protected"
        case .private: "Private"
        @unknown default: "Unknown"
        }
    }
}
