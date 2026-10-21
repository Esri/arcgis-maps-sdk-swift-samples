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

import Accessibility
import SwiftUI
import TipKit

extension UpdateLabelsAndSymbolsToScaleForVisualAccessibilityView {
    /// The inline tip and toolbar help, including access to system settings.
    struct TextSizeHelpView: View {
        /// An operational error routed to the currently visible presentation.
        @Binding var error: (any Error)?

        /// Opens the platform's accessibility settings.
        @Environment(\.openURL) private var openURL

        /// The text size used to decide whether to show inline instructions.
        @Environment(\.dynamicTypeSize) private var dynamicTypeSize

        /// Whether the available layout has a compact height.
        @Environment(\.verticalSizeClass) private var verticalSizeClass

        /// A Boolean value indicating whether the text-size instructions are presented.
        @State private var isShowingTextSizeHelp = false

        var body: some View {
            // Keep the help presentation available even when the inline tip is hidden.
            TipView(TextSizeTip()) { _ in
                openAccessibilitySettings()
            }
            .padding()
            .onAppear {
                // Configure tips on a best-effort basis, ignoring failures
                // such as tips already being configured for this process.
                try? Tips.configure([.displayFrequency(.immediate)])
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isShowingTextSizeHelp = true
                    } label: {
                        Label(
                            "Text Size Help",
                            systemImage: "textformat.size"
                        )
                    }
                }
            }
            .sheet(isPresented: $isShowingTextSizeHelp) {
                textSizeHelp
            }
            .errorAlert(presentingError: Binding(
                get: { isShowingTextSizeHelp ? nil : error },
                set: { error = $0 }
            ))
        }

        /// Instructions sharing this view's settings action and presentation state.
        private var textSizeHelp: some View {
            NavigationStack {
                Form {
                    UpdateLabelsAndSymbolsToScaleForVisualAccessibilityView.textSizeInstructions
                    Button("Open Accessibility Settings") {
                        openAccessibilitySettings()
                    }
                }
                .navigationTitle("Text Size")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            isShowingTextSizeHelp = false
                        }
                    }
                }
                .errorAlert(presentingError: $error)
            }
            .presentationDetents([.medium, .large])
        }

        /// Opens accessibility settings, with manual guidance if opening fails.
        private func openAccessibilitySettings() {
#if targetEnvironment(macCatalyst)
            openURL(.accessibilityDisplaySettings) { accepted in
                if !accepted {
                    error = OpenSettingsError()
                }
            }
#else
            Task {
                do {
                    // Use destinations supported by the current iOS version.
                    // The API has no explicit destination for Larger Text.
                    if #available(iOS 26.0, *) {
                        try await AccessibilitySettings.openSettings(
                            for: .assistiveTouchDevices
                        )
                    } else {
                        try await AccessibilitySettings.openSettings(
                            for: .personalVoiceAllowAppsToRequestToUse
                        )
                    }
                } catch {
                    self.error = OpenSettingsError()
                }
            }
#endif
        }

        /// An error opening settings, including manual navigation instructions.
        private struct OpenSettingsError: LocalizedError {
            var errorDescription: String? {
#if targetEnvironment(macCatalyst)
                String(localized: """
                    Unable to open settings. Open System Settings > \
                    Accessibility > Display > Text size manually.
                    """)
#else
                String(localized: """
                    Unable to open settings. Open Settings > Accessibility > \
                    Display & Text Size > Larger Text manually.
                    """)
#endif
            }
        }
    }
}

private extension URL {
    /// The Display pane of macOS Accessibility settings.
    static var accessibilityDisplaySettings: URL {
        URL(
            string: "x-apple.systempreferences:"
            + "com.apple.preference.universalaccess?Seeing_Display"
        )!
    }
}
