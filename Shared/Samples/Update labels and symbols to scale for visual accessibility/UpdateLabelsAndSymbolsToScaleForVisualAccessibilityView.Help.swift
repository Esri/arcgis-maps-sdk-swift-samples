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
    
    /// Manual instructions and best-effort access to Settings.
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
                // This undocumented scheme can stop working or cause App Store rejection.
                guard let url = URL(string: "App-prefs:ACCESSIBILITY") else {
                    openAppSettings()
                    return
                }
                openURL(url) { accepted in
                    if !accepted {
                        openAppSettings()
                    }
                }
            } label: {
                Label("Try Opening Settings", systemImage: "gear")
            }
            Text("The destination can vary. You may need to navigate manually to Accessibility and Larger Text. If the shortcut fails, the app's settings may open instead.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        
        private func openAppSettings() {
            guard let url = URL(string: UIApplication.openSettingsURLString) else {
                error = OpenSettingsError()
                return
            }
            openURL(url) { accepted in
                if !accepted {
                    error = OpenSettingsError()
                }
            }
        }
        
        /// An error opening settings, including manual navigation instructions.
        private struct OpenSettingsError: LocalizedError {
            var errorDescription: String? {
                "Unable to open Settings. Open the Settings app manually, then choose Accessibility > Display & Text Size > Larger Text."
            }
        }
    }
}
