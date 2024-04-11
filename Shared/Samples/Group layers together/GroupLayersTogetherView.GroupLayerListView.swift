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
                            LayerVisibilityToggle(formatLayerName(of: layer.name), layer: layer)
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
                LayerVisibilityToggle(groupLayer.name, layer: groupLayer)
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
    
    /// A toggle for changing a given layer's visibility.
    private struct LayerVisibilityToggle: View {
        /// The title of the toggle.
        private let title: String
        
        /// The layer with the visibility to change.
        private let layer: Layer
        
        /// A Boolean value indicating whether the layer's content is visible.
        @State private var isVisible: Bool
        
        /// Creates the toggle for changing a given layer's visibility.
        /// - Parameters:
        ///   - title: A string for the title of the toggle.
        ///   - layer: The layer with the visibility to change.
        init(_ title: String, layer: Layer) {
            self.title = title
            self.layer = layer
            self.isVisible = layer.isVisible
        }
        
        var body: some View {
            Toggle(title, isOn: $isVisible)
                .onChange(of: isVisible) { newValue in
                    layer.isVisible = newValue
                }
        }
    }
}
