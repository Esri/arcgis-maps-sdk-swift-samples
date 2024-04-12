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
    /// A list of settings for modifying route parameters.
    struct RouteParametersSettings: View {
        /// The route parameters to modify.
        private let routeParameters: RouteParameters
        
        /// A Boolean value indicating whether routing will find the best sequence.
        @State private var routingFindsBestSequence: Bool
        
        /// A Boolean value indicating whether routing will preserve the first stop.
        @State private var routePreservesFirstStop: Bool
        
        /// A Boolean value indicating whether routing will preserve the last stop.
        @State private var routePreservesLastStop: Bool
        
        init(for routeParameters: RouteParameters) {
            self.routeParameters = routeParameters
            self.routingFindsBestSequence = routeParameters.findsBestSequence
            self.routePreservesFirstStop = routeParameters.preservesFirstStop
            self.routePreservesLastStop = routeParameters.preservesLastStop
        }
        
        var body: some View {
            List {
                Toggle("Find Best Sequence", isOn: $routingFindsBestSequence)
                    .onChange(of: routingFindsBestSequence) { newValue in
                        routeParameters.findsBestSequence = newValue
                    }
                
                Section {
                    Toggle("Preserve First Stop", isOn: $routePreservesFirstStop)
                        .onChange(of: routePreservesFirstStop) { newValue in
                            routeParameters.preservesFirstStop = newValue
                        }
                    
                    Toggle("Preserve Last Stop", isOn: $routePreservesLastStop)
                        .onChange(of: routePreservesLastStop) { newValue in
                            routeParameters.preservesLastStop = newValue
                        }
                }
                .disabled(!routingFindsBestSequence)
            }
        }
    }
    
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
                    .frame(idealWidth: 320, minHeight: 240)
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
