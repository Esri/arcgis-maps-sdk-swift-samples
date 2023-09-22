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

extension GroupLayersTogetherView {
    struct GroupLayerListView: View {
        /// The group layer to display in the list section.
        let groupLayer: GroupLayer
        
        /// A Boolean that indicates whether the section body is disabled.
        @State private var isDisabled = false
        
        /// The name of the current visible child layer of a group layer with an exclusive visibility mode.
        @State private var exclusiveLayerSelection = ""
        
        var body: some View {
            Section {
                Group {
                    // Create a sublayer list based on the group layer's visibility mode.
                    switch groupLayer.visibilityMode {
                    case .independent:
                        // Toggles for sublayers that can change their visibility independently.
                        ForEach(groupLayer.layers, id: \.name) { layer in
                            Toggle(isOn: isVisibleBinding(for: layer)) {
                                Text(formatLayerName(of: layer.name))
                            }
                        }
                        
                    case .exclusive:
                        // Picker for when only one sublayer can be visible at a time.
                        Picker("Exclusive Layer", selection: $exclusiveLayerSelection) {
                            ForEach(groupLayer.layers, id: \.name) { layer in
                                Text(formatLayerName(of: layer.name))
                                    .onChange(of: exclusiveLayerSelection) { newValue in
                                        layer.isVisible = layer.name == newValue
                                    }
                            }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                        
                    case .inherited:
                        // Layer names for sublayers that are treated as one merged layer.
                        ForEach(groupLayer.layers, id: \.name) { layer in
                            Text(formatLayerName(of: layer.name))
                        }
                        
                    @unknown default:
                        fatalError("Unknown visibility mode: \(groupLayer.visibilityMode) for GroupLayer: \(groupLayer.name)")
                    }
                }
                .disabled(isDisabled)
            } header: {
                // The group layer visibility toggle.
                Toggle(isOn: isVisibleBinding(for: groupLayer)) {
                    Text(groupLayer.name)
                }
            }
            .task {
                // Listen for changes to is visible to disable the section
                // body when the group layer is not visible.
                for await isVisible in groupLayer.$isVisible {
                    isDisabled = !isVisible
                }
            }
            .onAppear {
                // Set the picker selection to the current visible child on appear.
                if groupLayer.visibilityMode == .exclusive {
                    exclusiveLayerSelection = groupLayer.layers.first(
                        where: { $0.isVisible == true }
                    )?.name ?? ""
                }
            }
        }
        
        /// Creates a custom binding for toggling a layers's visibility.
        /// - Parameter layer: The `Layer` to create the `Binding` from.
        /// - Returns: The new custom `Binding` object.
        private func isVisibleBinding(for layer: Layer) -> Binding<Bool> {
            return Binding(
                get: { layer.isVisible },
                set: { layer.isVisible = $0 }
            )
        }
        
        /// Formats a layer's name to be more human readable.
        /// - Parameter name: The original `String` name of the layer.
        /// - Returns: A `String` with the modified name or the original if the name is not found.
        private func formatLayerName(of name: String) -> String {
            switch name {
            case "DevA_Trees":
                return "Trees"
            case "DevA_Pathways":
                return "Pathways"
            case "DevA_BuildingShells":
                return "Buildings A"
            case "DevB_BuildingShells":
                return "Buildings B"
            case "DevelopmentProjectArea":
                return "Project Area"
            default:
                return name
            }
        }
    }
}
