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

extension Animate3DGraphicView {
    /// A view consisting of a sheet of settings controlled by a button.
    struct SettingsView<Content: View>: View {
        /// The name of the settings for the button and sheet title.
        let label: String
        
        /// The settings content to show in the sheet.
        @ViewBuilder let content: Content
        
        /// A Boolean value that indicates whether the sheet is currently showing.
        @State private var isPresented = false
        
        var body: some View {
            settingsButton
        }
        
        /// The settings button that brings up the settings sheet.
        @ViewBuilder private var settingsButton: some View {
            let button = Button(label) {
                isPresented = true
            }
            
            if #available(iOS 16, *) {
                button
                    .popover(isPresented: $isPresented, arrowEdge: .bottom) {
                        settingsContent
                            .presentationDetents([.fraction(0.5)])
#if targetEnvironment(macCatalyst)
                            .frame(minWidth: 300, minHeight: 270)
#else
                            .frame(minWidth: 320, minHeight: 390)
#endif
                    }
            } else {
                button
                    .sheet(isPresented: $isPresented) {
                        settingsContent
                    }
            }
        }
        
        /// The view content of the settings sheet.
        private var settingsContent: some View {
            NavigationView {
                content
                    .navigationTitle("\(label) Settings")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                isPresented = false
                            }
                        }
                    }
            }
            .navigationViewStyle(.stack)
        }
    }
}
