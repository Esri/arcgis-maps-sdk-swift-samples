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

@available(macCatalyst, unavailable)
extension UpdateLabelsAndSymbolsToScaleForVisualAccessibilityView {
    /// The selected restaurant's name and WGS 84 coordinates.
    struct RestaurantCalloutView: View {
        /// The selected restaurant.
        let feature: Feature
        
        /// The available map height for sizing the callout.
        let mapHeight: Double
        
        /// The callout's content height before any scrolling is needed.
        @State private var calloutContentHeight: Double?
        
        var body: some View {
            let name = (feature.attributes["name"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let location = (feature.geometry as? Point).flatMap {
                GeometryEngine.project($0, into: .wgs84)
            }
            let coordinateFormat = FloatingPointFormatStyle<Double>.number
                .precision(.fractionLength(5))
            
            ScrollView {
                VStack(alignment: .leading) {
                    Text(name.flatMap { $0.isEmpty ? nil : $0 } ?? "Restaurant")
                        .font(.headline)
                    if let location {
                        Text("Latitude: \(location.y, format: coordinateFormat)")
                        Text("Longitude: \(location.x, format: coordinateFormat)")
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding()
                .onGeometryChange(for: Double.self) { geometry in
                    Double(geometry.size.height)
                } action: { height in
                    calloutContentHeight = height
                }
            }
            // Let the callout container propose a smaller scrolling viewport.
            .frame(maxHeight: min(calloutContentHeight ?? mapHeight, mapHeight))
        }
    }
    
    /// Scrolling controls for the current scaling status and label setting.
    struct ScalingControlsView: View {
        /// The shared scaling settings edited by the toggle.
        @Bindable var model: Model
        
        /// An operational error presented by the sample.
        @Binding var error: (any Error)?
        
        var body: some View {
            Form {
                Section {
                    Toggle("Scale Labels Automatically", isOn: $model.labelsUseSystemTextScale)
                        .toggleStyle(.switch)
                        .accessibilityHint("Apply system text size to map labels. Symbols always follow system text size.")
                } header: {
                    Text("Label Scaling")
                } footer: {
                    Text("Symbols and callout text follow the system text size independently of this switch.")
                }

                Section("Scaling Legend") {
                    ScalingStatusView(model: model, error: $error)
                }

                Section("Change Text Size") {
                    TextSizeInstructionsView(error: $error)
                }
            }
        }
    }

    /// A legend showing scaling sources, current values, and the symbol swatch.
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
            let scaleFormat = FloatingPointFormatStyle<Double>.Percent()
                .precision(.fractionLength(0))
            let markerFormat = FloatingPointFormatStyle<Double>()
                .precision(.fractionLength(0...1))

            Label {
                VStack(alignment: .leading) {
                    Text("Map labels")
                    Text(model.labelsUseSystemTextScale ? "System text size" : "Fixed size")
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "textformat")
                    .accessibilityHidden(true)
            }
            Label {
                VStack(alignment: .leading) {
                    Text("Restaurant symbols")
                    Text("System text size")
                        .foregroundStyle(.secondary)
                }
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
                    .frame(width: model.markerSize, height: model.markerSize)
                    .accessibilityHidden(true)
                    .task(id: [model.markerSize, Double(displayScale)]) {
                        await updateMarkerSwatch(for: symbol)
                    }
                } else {
                    Image(systemName: "mappin.circle")
                        .accessibilityHidden(true)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Current Values")
                    .font(.headline)
                LabeledContent("System text scale (Body)", value: model.systemTextScale, format: scaleFormat)
                LabeledContent("Automatic label scaling", value: model.labelsUseSystemTextScale ? "On" : "Off")
                LabeledContent("Symbol size") {
                    Text("\(model.markerSize, format: markerFormat) pt")
                        .accessibilityLabel("\(model.markerSize, format: markerFormat) points")
                }
                Text("\(Model.baseMarkerSize, format: markerFormat) pt × \(model.systemTextScale, format: scaleFormat)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        
        /// Creates a swatch at the current size without changing the map symbol.
        private func updateMarkerSwatch(for symbol: MultilayerPointSymbol) async {
            do {
                let legendSymbol = symbol.clone()
                legendSymbol.size = model.markerSize
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
