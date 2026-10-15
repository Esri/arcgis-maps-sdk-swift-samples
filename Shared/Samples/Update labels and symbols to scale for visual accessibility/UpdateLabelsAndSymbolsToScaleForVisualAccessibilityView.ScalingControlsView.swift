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
    /// Content-sized controls, with a scrolling legend above the pinned toggle.
    struct ScalingControlsView: View {
        /// The shared scaling settings edited by the toggle.
        @Bindable var model: Model
        
        /// An operational error presented by the sample.
        @Binding var error: (any Error)?
        
        /// The legend's content height before any scrolling is needed.
        @State private var scalingStatusHeight: CGFloat?
        
        var body: some View {
            VStack(alignment: .leading) {
                ViewThatFits(in: .vertical) {
                    ScrollView {
                        ScalingStatusView(model: model, error: $error)
                            .fixedSize(horizontal: false, vertical: true)
                            .onGeometryChange(for: CGFloat.self) { geometry in
                                geometry.size.height
                            } action: { height in
                                scalingStatusHeight = height
                            }
                    }
                }
                Toggle("Scale Labels", isOn: $model.labelsUseSystemTextScale)
                    .toggleStyle(.switch)
                    .accessibilityHint(
                                       """
                                       Apply system text size to restaurant labels. \
                                       Symbols always follow the system text size.
                                       """
                    )
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
            }
            .padding()
            .background(.regularMaterial)
        }
    }
}
