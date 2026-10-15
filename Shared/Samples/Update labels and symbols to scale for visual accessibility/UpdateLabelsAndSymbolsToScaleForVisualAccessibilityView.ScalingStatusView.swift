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

import ArcGIS
import SwiftUI

extension UpdateLabelsAndSymbolsToScaleForVisualAccessibilityView {
    /// A legend showing the current scaling source, values, and symbol swatch.
    struct ScalingStatusView: View {
        /// The shared scaling settings and restaurant symbol.
        let model: Model
        
        /// An operational error presented by the sample.
        @Binding var error: (any Error)?
        
        /// A legend swatch matching the restaurant symbol's current size.
        @State private var markerSwatch: UIImage?
        
        /// The display scale used to render the legend swatch.
        @Environment(\.displayScale) private var displayScale
        
        var body: some View {
            let scaleFormat = FloatingPointFormatStyle<CGFloat>.Percent()
                .precision(.fractionLength(0))
            let markerFormat = FloatingPointFormatStyle<CGFloat>()
                .precision(.fractionLength(0...1))
            
            VStack(alignment: .leading) {
                Text(
                    """
                    System text scale (Body): \
                    \(model.systemTextScale, format: scaleFormat)
                    """
                )
                Label {
                    Text(
                        model.labelsUseSystemTextScale
                        ? "Labels: Dynamic Type" : "Labels: fixed size"
                    )
                } icon: {
                    Image(systemName: "textformat")
                        .bold()
                        .accessibilityHidden(true)
                }
                Label {
                    Text(
                        """
                        Symbols: Dynamic Type — \
                        \(Model.baseMarkerSize, format: markerFormat) pt × \
                        \(model.systemTextScale, format: scaleFormat) = \
                        \(model.markerSize, format: markerFormat) pt
                        """
                    )
                } icon: {
                    if let symbol = model.markerSymbol {
                        Group {
                            if let markerSwatch {
                                Image(uiImage: markerSwatch)
                                    .resizable()
                                    .scaledToFit()
                            } else {
                                Color.clear
                            }
                        }
                        .frame(
                            width: model.markerSize,
                            height: model.markerSize
                        )
                        .accessibilityHidden(true)
                        .task(id: [model.markerSize, displayScale]) {
                            await updateMarkerSwatch(for: symbol)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        
        /// Creates a swatch at the current size without changing the map symbol.
        private func updateMarkerSwatch(for symbol: MultilayerPointSymbol) async {
            do {
                let legendSymbol = symbol.clone()
                legendSymbol.size = Double(model.markerSize)
                let swatch = try await legendSymbol.makeSwatch(scale: displayScale)
                // Don't replace the image with a cancelled request's swatch.
                try Task.checkCancellation()
                markerSwatch = swatch
            } catch {
                if !Task.isCancelled {
                    self.error = error
                }
            }
        }
    }
}
