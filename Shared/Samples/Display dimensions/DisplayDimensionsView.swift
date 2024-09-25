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

struct DisplayDimensionsView: View {
    /// A map with no specified style.
    @State private var map = Map()
    
    /// The dimensional layer added to the map.
    @State private var dimensionLayer: DimensionLayer?
    
    /// A Boolean value indicating whether the dimension layer's content is visible.
    @State private var dimensionLayerIsVisible = true
    
    /// A Boolean value indicating whether the dimension layer's definition expression is set.
    @State private var definitionExpressionIsSet = false
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    var body: some View {
        MapView(map: map)
            .task {
                do {
                    try await loadDimensionLayer()
                } catch {
                    self.error = error
                }
            }
            .overlay {
                VStack {
                    Spacer()
                    Group {
                        Toggle("Dimension Layer", isOn: $dimensionLayerIsVisible)
                            .onChange(of: dimensionLayerIsVisible) { newValue in
                                dimensionLayer?.isVisible = newValue
                            }
                        
                        Toggle(
                            "Definition Expression:\nDimensions >= 450m",
                            isOn: $definitionExpressionIsSet
                        )
                        .onChange(of: definitionExpressionIsSet) { newValue in
                            dimensionLayer?.definitionExpression = newValue ? "DIMLENGTH >= 450" : ""
                        }
                    }
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
                    .disabled(dimensionLayer == nil)
                }
                .padding()
                .padding(.bottom)
            }
            .errorAlert(presentingError: $error)
    }
}

private extension DisplayDimensionsView {
    /// Loads a map with a dimension layer from a local mobile map package.
    private func loadDimensionLayer() async throws {
        // Load the local mobile map package using a URL.
        let mapPackage = MobileMapPackage(fileURL: .edinburghPylonDimensions)
        try await mapPackage.load()
        
        // Set the map to the first map in the mobile map package.
        if let map = mapPackage.maps.first {
            // Set the minScale to maintain dimension readability.
            map.minScale = 4e4
            self.map = map
        } else {
            throw SetupError.noMap
        }
        
        // Set the dimension layer using the one on the map.
        if let layer = map.operationalLayers.first(where: { $0 is DimensionLayer }) as? DimensionLayer {
            dimensionLayer = layer
        } else {
            throw SetupError.noDimensionLayer
        }
    }
    
    /// The errors for the sample that can be thrown during setup.
    private enum SetupError: String, LocalizedError {
        case noMap = "The MMPK does not contain a map."
        case noDimensionLayer = "The map does not contain a dimension layer."
        
        /// The text description of the error.
        var errorDescription: String? {
            NSLocalizedString(
                self.rawValue,
                comment: "Error thrown when the setup for the sample fails."
            )
        }
    }
}

private extension URL {
    /// The URL to the local Edinburgh Pylon Dimensions mobile map package file.
    static var edinburghPylonDimensions: URL {
        Bundle.main.url(forResource: "Edinburgh_Pylon_Dimensions", withExtension: "mmpk")!
    }
}
