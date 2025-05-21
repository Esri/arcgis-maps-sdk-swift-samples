// Copyright 2025 Esri
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

extension ControlAnnotationSublayerVisibilityView {
    /// The view model for this sample.
    @MainActor
    class Model: ObservableObject {
        /// A map from the mobile map package.
        @Published private(set) var map = Map()
        
        /// The mobile map package.
        private var mobileMapPackage: MobileMapPackage!
        
        /// The annotation layer in the map.
        private var annotationLayer: AnnotationLayer?
        
        /// The closed annotation sublayer.
        private var closedSublayer: AnnotationSublayer?
        
        /// The open annotation sublayer.
        private var openSublayer: AnnotationSublayer?
        
        /// A Boolean value indicating whether to show the closed annotation sublayer.
        @Published var showsClosedSublayer = true
        
        /// A Boolean value indicating whether to show the open annotation sublayer.
        @Published var showsOpenSublayer = true
        
        /// A Boolean value indicating whether the open annotation sublayer is visible at the current extent.
        @Published var visibleAtCurrentExtent = false
        
        /// The current scale of the map.
        var currentScale: Double = .zero {
            didSet {
                currentScaleText = "1:\(currentScale.formatted(.decimal))"
                guard let openSublayer else { return }
                visibleAtCurrentExtent = openSublayer.isVisible(atScale: currentScale)
            }
        }
        
        /// The map's current scale value in text.
        @Published var currentScaleText = ""
        
        /// The min and max scale of the open annotation layer in text.
        @Published var minMaxScaleText = ""
        
        /// Loads a local mobile map package.
        func loadMobileMapPackage() async throws {
            mobileMapPackage = MobileMapPackage(fileURL: .gasDevicePackage)
            try await mobileMapPackage.load()
            guard let map = mobileMapPackage.maps.first else { return }
            self.map = map
        }
        
        /// Sets the map's annotation layer and sublayers.
        func setAnnotationSublayers() {
            annotationLayer = map.operationalLayers.first(where: { $0 is AnnotationLayer }) as? AnnotationLayer
            closedSublayer = annotationLayer?.subLayerContents[0] as? AnnotationSublayer
            openSublayer = annotationLayer?.subLayerContents[1] as? AnnotationSublayer
            setScaleText()
        }
        
        /// Sets the visibility of the closed annotation sublayer.
        /// - Parameter visibility: The visibility of the sublayer.
        func setClosedSublayerVisibility(_ visibility: Bool) {
            closedSublayer?.isVisible = visibility
        }
        
        /// Sets the visibility of the open annotation sublayer.
        /// - Parameter visibility: The visibility of the sublayer.
        func setOpenSublayerVisibility(_ visibility: Bool) {
            openSublayer?.isVisible = visibility
        }
        
        /// Sets the min and max scale and formats the min-max scale text.
        private func setScaleText() {
            guard let openSublayer,
                  let minScale = openSublayer.minScale,
                  let maxScale = openSublayer.maxScale else { return }
            minMaxScaleText = "Open (1:\(minScale.formatted(.decimal)) - 1:\(maxScale.formatted(.decimal)))"
        }
    }
}

private extension FormatStyle where Self == FloatingPointFormatStyle<Double> {
    /// Formats the double with zero decimals places of precision.
    static var decimal: Self {
        Self.number.precision(.fractionLength(0))
    }
}

private extension URL {
    /// The URL to the local Gas Device Annotation mobile map package file.
    static var gasDevicePackage: URL {
        Bundle.main.url(forResource: "GasDeviceAnno", withExtension: "mmpk")!
    }
}
