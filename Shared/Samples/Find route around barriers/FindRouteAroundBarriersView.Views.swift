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

extension FindRouteAroundBarriersView {
    
    /// A button with a given label that brings up a sheet containing given content.
    struct SheetButton<Content: View, Label: View>: View {
        /// The string to display as the title of the sheet
        let title: String
        
        /// A view that contains the content to display in the sheet.
        let content: () -> Content
        
        /// A view that describes the purpose of the button.
        let label: () -> Label
        
        /// A Boolean value indicating whether the sheet is showing.
        @State private var sheetIsShowing = false
        
        var body: some View {
            Button {
                sheetIsShowing = true
            } label: {
                label()
            }
            .popover(isPresented: $sheetIsShowing) {
                sheetContent
                    .presentationDetents([.fraction(0.5)])
                    .frame(idealWidth: 320, idealHeight: 240)
            }
        }
        
        /// The content to display in the sheet with a title and done button.
        private var sheetContent: some View {
            NavigationStack {
                content()
                    .navigationTitle(title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                sheetIsShowing = false
                            }
                        }
                    }
            }
        }
    }
}
