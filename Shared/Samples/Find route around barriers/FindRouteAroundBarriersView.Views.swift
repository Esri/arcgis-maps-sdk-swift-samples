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
        
        /// The route features to be added or removed from the map.
        @State private var featuresSelection: RouteFeatures = .stops
        
        @Binding private var isDoneTapped: Bool
        
        init(for routeParameters: RouteParameters, doneTapped: Binding<Bool>) {
            self.routeParameters = routeParameters
            self.routingFindsBestSequence = routeParameters.findsBestSequence
            self.routePreservesFirstStop = routeParameters.preservesFirstStop
            self.routePreservesLastStop = routeParameters.preservesLastStop
            self._isDoneTapped = doneTapped
        }
        
        //        var body: some View {
        //            List {
        //                Toggle("Find Best Sequence", isOn: $routingFindsBestSequence)
        //                    .onChange(of: routingFindsBestSequence) {
        //                        routeParameters.findsBestSequence = routingFindsBestSequence
        //                    }
        //
        //                Section {
        //                    Toggle("Preserve First Stop", isOn: $routePreservesFirstStop)
        //                        .onChange(of: routePreservesFirstStop) {
        //                            routeParameters.preservesFirstStop = routePreservesFirstStop
        //                        }
        //
        //                    Toggle("Preserve Last Stop", isOn: $routePreservesLastStop)
        //                        .onChange(of: routePreservesLastStop) {
        //                            routeParameters.preservesLastStop = routePreservesLastStop
        //                        }
        //                }
        //                .disabled(!routingFindsBestSequence)
        //            }
        //        }
        //    }
        
        var body: some View {
            NavigationStack {
                Form {
                    Section("Features") {
                        Picker("Features", selection: $featuresSelection) {
                            Text("Stops").tag(RouteFeatures.stops)
                            Text("Barriers").tag(RouteFeatures.barriers)
                        }
                        .pickerStyle(.segmented)
                    }
                    Section {
                        Toggle("Find Best Sequence", isOn: $routingFindsBestSequence)
                    }
                    
                    Section("Preserve Stops") {
                        Toggle("Preserve First Stop", isOn: $routePreservesFirstStop)
                        Toggle("Preserve Last Stop", isOn: $routePreservesLastStop)
                    }
                    .disabled(!routeParameters.findsBestSequence)
                }
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            isDoneTapped = false
//                            showSettings = false
                        }
                    }
                }
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
                   
                    .frame(idealWidth: 320, idealHeight: 240)
                    .presentationCompactAdaptation(.popover)
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
