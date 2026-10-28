// Copyright 2026 Esri
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
import UIKit

@available(macCatalyst, unavailable)
extension UpdateLabelsAndSymbolsToScaleForVisualAccessibilityView {
    /// Text-size instructions and access to system settings.
    struct TextSizeHelpView: View {
        /// An operational error routed to the currently visible presentation.
        @Binding var error: (any Error)?
        
        @Environment(\.dismiss) private var dismiss
        
        var body: some View {
            NavigationStack {
                Form {
                    Section("Change Text Size") {
                        TextSizeInstructionsView(error: $error)
                    }
                    Text("Select a restaurant to view its name and coordinates.")
                }
                .navigationTitle("Text Size")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
                .errorAlert(presentingError: $error)
            }
            .presentationDetents([.medium, .large])
        }
    }

    /// Manual instructions and the supported app-specific Settings destination.
    struct TextSizeInstructionsView: View {
        /// An operational error routed to the currently visible presentation.
        @Binding var error: (any Error)?
        @Environment(\.openURL) private var openURL

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("Open Settings > Accessibility > Display & Text Size > Larger Text.")
                Text("Adjust the slider. Enable Larger Accessibility Sizes for more options, then return to the sample.")
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)

            Button {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                openURL(url) { accepted in
                    if !accepted {
                        error = OpenSettingsError()
                    }
                }
            } label: {
                Label("Open App Settings", systemImage: "gear")
            }
            Text("iOS cannot open Larger Text directly. From App Settings, navigate back to Settings, then follow the path above.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }

        /// An error opening settings, including manual navigation instructions.
        private struct OpenSettingsError: LocalizedError {
            var errorDescription: String? {
                "Unable to open App Settings. Open Settings > Accessibility > Display & Text Size > Larger Text manually."
            }
        }
    }
}
